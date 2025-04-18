package org.xhy.application.conversation.service.message.agentv2.executor;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
import dev.langchain4j.model.openai.OpenAiChatOptions;
import dev.langchain4j.model.openai.OpenAiTools;
import dev.langchain4j.service.tool.ToolExecutionRequest;
import dev.langchain4j.service.tool.ToolSpecification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.dto.AgentChatResponse;
import org.xhy.application.conversation.service.handler.content.ChatContext;
import org.xhy.application.conversation.service.message.agent.manager.AgentToolManager;
import org.xhy.domain.conversation.constant.MessageType;
import org.xhy.domain.conversation.model.MessageEntity;
import org.xhy.domain.conversation.service.MessageDomainService;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.transport.MessageTransport;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;

/**
 * Agent循环执行器
 * 简化版本，大模型自主决定工具调用
 */
@Component
public class AgentLoopExecutor {

    private static final Logger log = LoggerFactory.getLogger(AgentLoopExecutor.class);

    @Value("${agent.max-iterations:30}")
    private int maxIterations;

    private final LLMServiceFactory llmServiceFactory;
    private final AgentToolManager agentToolManager;
    private final MessageDomainService messageDomainService;

    public AgentLoopExecutor(
            LLMServiceFactory llmServiceFactory,
            AgentToolManager agentToolManager,
            MessageDomainService messageDomainService) {
        this.llmServiceFactory = llmServiceFactory;
        this.agentToolManager = agentToolManager;
        this.messageDomainService = messageDomainService;
    }

    /**
     * 执行Agent循环
     */
    public <T> void execute(
            ChatContext chatContext,
            MessageEntity userMessageEntity,
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport,
            Supplier<Boolean> shouldInterrupt) {

        String sessionId = chatContext.getSessionId();
        log.info("开始执行Agent循环, 会话ID: {}", sessionId);

        // 准备消息历史
        List<ChatMessage> messages = buildChatHistory(chatContext);

        // 准备工具
        List<String> availableTools = agentToolManager.getAvailableTools();

        // 创建流式响应处理器
        StringBuilder responseBuilder = new StringBuilder();
        StreamingChatResponseHandler handler = createResponseHandler(
                responseBuilder, connection, messageTransport, shouldInterrupt);

        // 获取流式模型
        StreamingChatLanguageModel model = llmServiceFactory.getStreamingClient(
                chatContext.getProvider(),
                chatContext.getModel());

        // 执行循环
        int iteration = 0;
        boolean continueExecution = true;

        try {
            while (continueExecution && iteration < maxIterations) {
                // 检查是否应该中断
                if (shouldInterrupt.get()) {
                    log.info("Agent循环被中断, 会话ID: {}", sessionId);
                    messageTransport.sendMessage(connection,
                            AgentChatResponse.build("任务已中断", MessageType.TEXT));
                    break;
                }

                iteration++;
                log.info("执行Agent循环迭代 {}/{}, 会话ID: {}", iteration, maxIterations, sessionId);

                // 清空当前响应构建器
                responseBuilder.setLength(0);

                // 调用模型获取响应
                AiMessage response;
                try {
                    // 对于支持工具调用格式的模型，可以设置工具规范
                    response = model.generate(messages, handler);

                    // 添加AI回复到消息历史
                    messages.add(response);

                    // 检查响应中是否包含工具调用指令
                    // 工具调用指令的检测可能需要分析文本，这取决于大模型的输出格式
                    // 这里简化处理，假设模型会输出特定格式的工具调用指令
                    String responseText = response.text();
                    List<ToolExecutionRequest> toolRequests = extractToolRequests(responseText);

                    if (!toolRequests.isEmpty()) {
                        // 有工具调用，处理每个工具调用
                        for (ToolExecutionRequest request : toolRequests) {
                            // 发送工具调用消息
                            messageTransport.sendMessage(connection,
                                    AgentChatResponse.build("调用工具: " + request.name(), MessageType.TOOL_CALL));

                            // 执行工具并获取结果
                            String result;
                            try {
                                // 通过AgentToolManager执行工具调用
                                result = executeToolCall(request.name(), request.arguments());
                            } catch (Exception e) {
                                log.error("执行工具调用失败", e);
                                result = "工具执行错误: " + e.getMessage();
                            }

                            // 发送工具结果
                            messageTransport.sendMessage(connection,
                                    AgentChatResponse.build(result, MessageType.TOOL_RESULT));

                            // 添加工具调用结果到历史
                            messages.add(new SystemMessage("工具执行结果:\n" + result));
                        }

                        // 添加提示继续处理
                        messages.add(new SystemMessage(
                                "基于以上工具执行结果，请继续。如果任务已完成，请直接提供最终答案，无需再调用工具。"));
                    } else {
                        // 无工具调用，完成执行
                        continueExecution = false;
                    }
                } catch (RuntimeException e) {
                    if (e.getCause() instanceof InterruptedException) {
                        log.info("Agent循环被中断, 会话ID: {}", sessionId);
                        break;
                    }
                    throw e;
                }
            }
        } catch (Exception e) {
            log.error("执行Agent循环出错", e);
            messageTransport.sendMessage(connection,
                    AgentChatResponse.build("执行出错: " + e.getMessage(), MessageType.ERROR));
        }

        // 如果达到最大迭代次数
        if (iteration >= maxIterations && continueExecution) {
            log.warn("达到最大迭代次数 {}, 会话ID: {}", maxIterations, sessionId);
            messageTransport.sendMessage(connection,
                    AgentChatResponse.build("达到最大处理次数限制，任务被中止。", MessageType.WARNING));
        }

        // 保存最终的助手回复
        llmMessageEntity.setContent(responseBuilder.toString());
        messageDomainService.saveMessage(llmMessageEntity);

        // 发送结束消息
        messageTransport.sendMessage(connection,
                AgentChatResponse.buildEndMessage(MessageType.TEXT_STREAM));

        log.info("Agent循环执行完成, 总迭代次数: {}, 会话ID: {}", iteration, sessionId);
    }

    /**
     * 构建聊天历史
     */
    private List<ChatMessage> buildChatHistory(ChatContext chatContext) {
        List<ChatMessage> messages = new ArrayList<>();

        // 添加系统提示
        messages.add(new SystemMessage("你是一个智能助手，能够理解和解决复杂问题。当你需要查询信息或执行操作时，" +
                "你可以使用工具。请按照以下格式调用工具：\n\n" +
                "调用工具: [工具名称]\n参数: [工具参数]\n\n" +
                "完成任务后，提供一个清晰、详细的回答。"));

        // 获取历史消息
        List<MessageEntity> historyMessages = messageDomainService.getMessagesBySessionId(
                chatContext.getSessionId(), chatContext.getLlmModelConfig().getContextSize() - 5);

        // 添加历史消息
        for (MessageEntity msg : historyMessages) {
            if (msg.isUserMessage()) {
                messages.add(new UserMessage(msg.getContent()));
            } else if (msg.isAssistantMessage()) {
                messages.add(new AiMessage(msg.getContent()));
            }
        }

        // 添加当前用户消息
        messages.add(new UserMessage(chatContext.getUserMessage()));

        return messages;
    }

    /**
     * 从响应文本中提取工具调用请求
     */
    private List<ToolExecutionRequest> extractToolRequests(String responseText) {
        List<ToolExecutionRequest> requests = new ArrayList<>();

        // 简单实现：检测特定格式的工具调用，如"调用工具: [工具名称]\n参数: [参数]"
        // 实际实现可能需要更复杂的解析，可能使用正则表达式或JSON解析

        // 这里是简化版实现，实际项目中可能需要更精确的解析
        if (responseText.contains("调用工具:")) {
            String[] lines = responseText.split("\n");
            String toolName = null;
            StringBuilder args = new StringBuilder();

            for (String line : lines) {
                line = line.trim();
                if (line.startsWith("调用工具:")) {
                    toolName = line.substring("调用工具:".length()).trim();
                } else if (line.startsWith("参数:") && toolName != null) {
                    args.append(line.substring("参数:".length()).trim());

                    // 创建工具调用请求
                    ToolExecutionRequest request = new ToolExecutionRequest("request-" + Math.random(), toolName,
                            args.toString());
                    requests.add(request);

                    // 重置
                    toolName = null;
                    args.setLength(0);
                }
            }
        }

        return requests;
    }

    /**
     * 执行工具调用
     */
    private String executeToolCall(String toolName, String arguments) {
        // 这里应该调用AgentToolManager执行工具
        // 由于我们复用现有代码，这里实现可能需要适配

        // 模拟工具执行
        log.info("执行工具: {}, 参数: {}", toolName, arguments);

        // 实际应该使用AgentToolManager调用工具
        return "工具执行结果：这是一个示例结果，实际实现需要调用对应工具";
    }

    /**
     * 创建带中断检查的响应处理器
     */
    private <T> StreamingChatResponseHandler createResponseHandler(
            StringBuilder responseBuilder,
            T connection,
            MessageTransport<T> messageTransport,
            Supplier<Boolean> shouldInterrupt) {

        return new StreamingChatResponseHandler() {
            @Override
            public void onNext(String token) {
                try {
                    // 检查是否应该中断
                    if (shouldInterrupt.get()) {
                        throw new InterruptedException("任务被中断");
                    }

                    // 添加到响应
                    responseBuilder.append(token);

                    // 发送到前端
                    messageTransport.sendMessage(connection,
                            AgentChatResponse.build(token, MessageType.TEXT_STREAM));
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }

            @Override
            public void onComplete() {
                // 完成时不做特殊处理
            }

            @Override
            public void onError(Throwable error) {
                messageTransport.handleError(connection, error);
            }
        };
    }
}