package org.xhy.application.conversation.service.message.agentv2.executor;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
import dev.langchain4j.service.AiServices;
import dev.langchain4j.service.tool.ToolProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.dto.AgentChatResponse;
import org.xhy.application.conversation.service.handler.content.ChatContext;
import org.xhy.application.conversation.service.message.agent.Agent;
import org.xhy.application.conversation.service.message.agent.manager.AgentToolManager;
import org.xhy.application.conversation.service.message.agent.template.AgentPromptTemplates;
import org.xhy.domain.conversation.constant.MessageType;
import org.xhy.domain.conversation.model.MessageEntity;
import org.xhy.domain.conversation.service.MessageDomainService;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.transport.MessageTransport;

import java.util.ArrayList;
import java.util.Collections;
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
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport,
            Supplier<Boolean> shouldInterrupt) {

        String sessionId = chatContext.getSessionId();
        log.info("开始执行Agent循环, 会话ID: {}", sessionId);

        // 准备工具
        List<String> availableTools = agentToolManager.getAvailableTools();
        ToolProvider toolProvider = agentToolManager.createToolProvider(availableTools);
        
        // 存储执行过程和工具调用结果
        StringBuilder executionProcess = new StringBuilder();
        
        // 获取普通聊天模型
        ChatLanguageModel model = llmServiceFactory.getStrandClient(
                chatContext.getProvider(),
                chatContext.getModel());

        // 创建Agent服务，修改提示词以引导展示思考过程
        Agent agent = AiServices.builder(Agent.class)
                .chatLanguageModel(model)
                .toolProvider(toolProvider)
                .build();

        // 执行循环
        int iteration = 0;
        boolean continueExecution = true;
        AiMessage lastAiMessage = null;

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

                try {
                    // 构建提示词，包含用户原始请求和之前的执行结果
                    String prompt;
                    if (iteration == 1) {
                        // 第一次迭代使用原始用户请求，并引导展示思考过程
                        prompt = "请解决以下问题，在回答过程中请先阐述你的思考过程，然后再给出结论或执行工具调用：\n\n" + 
                                chatContext.getUserMessage();
                    } else {
                        // 后续迭代，包含前一次AI响应
                        prompt = "基于之前的执行结果，请继续处理用户请求。请先阐述当前的思考过程，然后再给出结论或执行工具调用：\n\n" + 
                                chatContext.getUserMessage();
                    }

                    // 调用模型获取响应
                    lastAiMessage = agent.chat(prompt);
                    
                    // 记录执行过程
                    executionProcess.append("迭代 ").append(iteration).append(":\n")
                                    .append(lastAiMessage.text()).append("\n\n");
                    
                    // 处理工具调用
                    if (lastAiMessage.hasToolExecutionRequests()) {
                        // 发送思考过程给前端（在工具调用前的文本）
                        String thinking = lastAiMessage.text().split("调用工具")[0];
                        if (!thinking.trim().isEmpty()) {
                            messageTransport.sendMessage(connection,
                                    AgentChatResponse.build(thinking, MessageType.TEXT));
                        }
                        
                        handleToolCalls(lastAiMessage, connection, messageTransport, chatContext);
                        
                        // 还需要继续执行
                        continueExecution = true;
                    } else {
                        // 无工具调用，任务已完成，不再继续执行
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
            
            // 任务执行完成后，调用润色
            if (!shouldInterrupt.get()) {
                generateFinalResponse(chatContext, executionProcess.toString(), llmMessageEntity, 
                        connection, messageTransport, shouldInterrupt);
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
                    AgentChatResponse.build("达到最大处理次数限制", MessageType.WARNING));
            
            // 即使达到最大迭代次数，仍然尝试生成最终回复
            generateFinalResponse(chatContext, executionProcess.toString(), llmMessageEntity, 
                    connection, messageTransport, shouldInterrupt);
        }
        
        log.info("Agent循环执行完成, 总迭代次数: {}, 会话ID: {}", iteration, sessionId);
    }
    
    /**
     * 生成最终回复
     * 调用模型进行润色并通过流式方式返回
     */
    private <T> void generateFinalResponse(
            ChatContext chatContext,
            String executionProcess,
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport,
            Supplier<Boolean> shouldInterrupt) {
        
        log.info("生成最终润色回复, 会话ID: {}", chatContext.getSessionId());
        
        try {

            // 创建请求
            ChatRequest request = chatContext.prepareChatRequest()
                    .messages(Collections.singletonList(
                        new SystemMessage(
                                AgentPromptTemplates.getSummaryPrompt(executionProcess))))
                    .build();
            
            // 使用流式模型获取润色后的回答
            StreamingChatLanguageModel streamingModel = llmServiceFactory.getStreamingClient(
                    chatContext.getProvider(), 
                    chatContext.getModel());
            
            streamingModel.doChat(request, new StreamingChatResponseHandler() {
                @Override
                public void onPartialResponse(String token) {
                    // 检查是否应该中断
                    if (shouldInterrupt.get()) {
                        throw new RuntimeException(new InterruptedException("任务被中断"));
                    }
                    messageTransport.sendMessage(connection,
                            AgentChatResponse.build(token, MessageType.TEXT));
                }
                
                @Override
                public void onCompleteResponse(ChatResponse response) {
                    // 保存最终润色后的回复
                    llmMessageEntity.setContent(response.aiMessage().text());
                    // 保存消息并更新上下文
                    messageDomainService.saveMessageAndUpdateContext(
                            Collections.singletonList(llmMessageEntity),
                            chatContext.getContextEntity());
                            
                    // 发送结束消息
                    messageTransport.sendMessage(connection,
                            AgentChatResponse.buildEndMessage(MessageType.TEXT));
                            
                    log.info("最终润色回复已完成并保存, 会话ID: {}", chatContext.getSessionId());
                }
                
                @Override
                public void onError(Throwable error) {
                    messageTransport.handleError(connection, error);
                }
            });
            
        } catch (Exception e) {
            log.error("生成最终回复出错", e);
            messageTransport.handleError(connection, e);
        }
    }

    /**
     * 处理工具调用
     */
    private <T> void handleToolCalls(
            AiMessage aiMessage,
            T connection,
            MessageTransport<T> messageTransport,
            ChatContext chatContext) {
        
        // 创建工具调用消息
        StringBuilder toolCallsContent = new StringBuilder("工具调用:\n");

        List<MessageEntity> messages = new ArrayList<>();
        aiMessage.toolExecutionRequests().forEach(toolExecutionRequest -> {
            String toolName = toolExecutionRequest.name();
            toolCallsContent.append("- ").append(toolName).append("\n");
            
            // 通知前端工具调用
            messageTransport.sendMessage(connection,
                    AgentChatResponse.build(toolName, MessageType.TOOL_CALL));
            
            // 这里可以记录工具执行请求的详细信息
            log.info("工具调用: {}, 参数: {}", toolName, toolExecutionRequest.arguments());

            MessageEntity toolCallMessageEntity = new MessageEntity();
            toolCallMessageEntity.setSessionId(chatContext.getSessionId());
            toolCallMessageEntity.setContent(toolCallsContent.toString());
            toolCallMessageEntity.setMessageType(MessageType.TOOL_CALL);
            messages.add(toolCallMessageEntity);
        });
        messageDomainService.saveMessageAndUpdateContext(messages,chatContext.getContextEntity());
    }
}