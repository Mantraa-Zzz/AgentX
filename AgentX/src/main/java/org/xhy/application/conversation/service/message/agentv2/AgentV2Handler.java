package org.xhy.application.conversation.service.message.agentv2;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.dto.AgentChatResponse;
import org.xhy.application.conversation.service.handler.content.ChatContext;
import org.xhy.application.conversation.service.message.AbstractMessageHandler;
import org.xhy.application.conversation.service.message.agentv2.analyzer.MessageAnalyzer;
import org.xhy.application.conversation.service.message.agentv2.analysis.dto.AnalysisResultDTO;
import org.xhy.application.conversation.service.message.agentv2.executor.AgentLoopExecutor;
import org.xhy.domain.conversation.constant.MessageType;
import org.xhy.domain.conversation.model.MessageEntity;
import org.xhy.domain.conversation.service.ConversationDomainService;
import org.xhy.domain.conversation.service.ContextDomainService;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.transport.MessageTransport;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * AgentV2处理器
 * 简化版Agent实现，支持随时中断和用户干预
 */
@Component("agentV2Handler")
public class AgentV2Handler extends AbstractMessageHandler {

    private static final Logger log = LoggerFactory.getLogger(AgentV2Handler.class);
    protected static final int CONNECTION_TIMEOUT = (int) TimeUnit.MINUTES.toMillis(30);

    private final AgentLoopExecutor agentLoopExecutor;
    private final MessageAnalyzer messageAnalyzer;

    // 记录正在执行的会话，用于中断控制
    private final Map<String, Boolean> activeExecutions = new ConcurrentHashMap<>();

    public AgentV2Handler(
            ConversationDomainService conversationDomainService,
            ContextDomainService contextDomainService,
            LLMServiceFactory llmServiceFactory,
            AgentLoopExecutor agentLoopExecutor,
            MessageAnalyzer messageAnalyzer) {
        super(conversationDomainService, contextDomainService, llmServiceFactory);
        this.agentLoopExecutor = agentLoopExecutor;
        this.messageAnalyzer = messageAnalyzer;
    }

    @Override
    public <T> T chat(ChatContext chatContext, MessageTransport<T> messageTransport) {
        String sessionId = chatContext.getSessionId();
        String userInput = chatContext.getUserMessage();

        log.info("处理用户消息, 会话ID: {}, 消息: {}", sessionId, userInput);

        // 检查是否有正在执行的会话，如果有则中断
        if (activeExecutions.containsKey(sessionId)) {
            activeExecutions.put(sessionId, false); // 标记为需要中断
            log.info("中断会话 {} 的正在执行的任务", sessionId);

            // 发送中断消息（仅在调试环境）
            // messageTransport.sendMessage(connection,
            // AgentChatResponse.build("任务已中断，处理新的指令...", MessageType.TEXT));
        }

        // 创建用户消息和LLM消息实体
        MessageEntity userMessageEntity = this.createUserMessage(chatContext);
        MessageEntity llmMessageEntity = createLlmMessage(chatContext);

        // 创建连接
        T connection = messageTransport.createConnection(CONNECTION_TIMEOUT);

        // 分析用户消息
        CompletableFuture.runAsync(() -> {
            try {
                // 标记会话为活跃
                activeExecutions.put(sessionId, true);

                // 分析用户消息类型
                AnalysisResultDTO analysisResult = messageAnalyzer.analyzeMessage(chatContext);

                if (analysisResult.isQuestion()) {
                    // 普通消息，直接回复
                    handleNormalMessage(chatContext, userMessageEntity, llmMessageEntity,
                            connection, messageTransport);
                } else {
                    // 任务消息，执行Agent循环
                    handleTaskMessage(chatContext, userMessageEntity, llmMessageEntity,
                            connection, messageTransport);
                }
            } catch (Exception e) {
                log.error("处理消息时发生错误", e);
                messageTransport.handleError(connection, e);
            } finally {
                // 结束时移除活跃标记
                activeExecutions.remove(sessionId);
                // 关闭连接
                messageTransport.completeConnection(connection);
            }
        });

        // 立即返回连接
        return connection;
    }

    /**
     * 处理普通消息
     */
    private <T> void handleNormalMessage(
            ChatContext chatContext,
            MessageEntity userMessageEntity,
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport) {

        String sessionId = chatContext.getSessionId();
        log.info("处理普通消息, 会话ID: {}", sessionId);

        // 保存用户消息
        conversationDomainService.saveMessage(userMessageEntity);

        // 准备中断检查函数
        final Runnable checkInterruption = () -> {
            if (!activeExecutions.getOrDefault(sessionId, true)) {
                throw new InterruptedException("任务被用户中断");
            }
        };

        try {
            // 使用标准流式回复，带中断检查
            streamResponseWithInterruptCheck(chatContext, llmMessageEntity, connection,
                    messageTransport, checkInterruption);
        } catch (InterruptedException e) {
            log.info("普通消息处理被中断, 会话ID: {}", sessionId);
        }
    }

    /**
     * 处理任务消息
     */
    private <T> void handleTaskMessage(
            ChatContext chatContext,
            MessageEntity userMessageEntity,
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport) {

        String sessionId = chatContext.getSessionId();
        log.info("处理任务消息, 会话ID: {}", sessionId);

        // 保存用户消息
        conversationDomainService.saveMessage(userMessageEntity);

        // 执行Agent循环
        agentLoopExecutor.execute(
                chatContext,
                userMessageEntity,
                llmMessageEntity,
                connection,
                messageTransport,
                () -> !activeExecutions.getOrDefault(sessionId, false) // 中断检查函数
        );
    }

    /**
     * 带中断检查的流式响应
     * 在每个token发送后检查是否应该中断
     */
    private <T> void streamResponseWithInterruptCheck(
            ChatContext chatContext,
            MessageEntity llmMessageEntity,
            T connection,
            MessageTransport<T> messageTransport,
            Runnable checkInterruption) throws InterruptedException {

        // 创建流式响应处理器
        StringBuilder responseBuilder = new StringBuilder();

        // 获取流式模型
        var streamingModel = llmServiceFactory.getStreamingClient(
                chatContext.getProvider(), chatContext.getModel());

        // 构建消息历史
        var messages = buildChatHistory(chatContext);

        // 进行流式调用
        streamingModel.generate(messages, new StreamingResponseHandlerWithInterruptCheck<>(
                responseBuilder, connection, messageTransport, checkInterruption));

        // 保存完整的助手回复
        llmMessageEntity.setContent(responseBuilder.toString());
        conversationDomainService.saveMessage(llmMessageEntity);

        // 发送结束消息
        messageTransport.sendMessage(connection,
                AgentChatResponse.buildEndMessage(MessageType.TEXT_STREAM));
    }

    /**
     * 支持中断检查的流式响应处理器
     */
    private static class StreamingResponseHandlerWithInterruptCheck<T>
            implements dev.langchain4j.model.chat.response.StreamingChatResponseHandler {

        private final StringBuilder responseBuilder;
        private final T connection;
        private final MessageTransport<T> messageTransport;
        private final Runnable checkInterruption;

        public StreamingResponseHandlerWithInterruptCheck(
                StringBuilder responseBuilder,
                T connection,
                MessageTransport<T> messageTransport,
                Runnable checkInterruption) {
            this.responseBuilder = responseBuilder;
            this.connection = connection;
            this.messageTransport = messageTransport;
            this.checkInterruption = checkInterruption;
        }

        @Override
        public void onNext(String token) {
            try {
                // 检查是否应该中断
                checkInterruption.run();

                // 添加到完整响应
                responseBuilder.append(token);

                // 发送到前端
                messageTransport.sendMessage(connection,
                        AgentChatResponse.build(token, MessageType.TEXT_STREAM));
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        }

        @Override
        public void onComplete() {
            // 流完成时无需操作
        }

        @Override
        public void onError(Throwable error) {
            try {
                messageTransport.handleError(connection, error);
            } catch (Exception e) {
                // 忽略处理错误的错误
            }
        }
    }

    /**
     * 构建聊天历史
     */
    private List<dev.langchain4j.data.message.ChatMessage> buildChatHistory(ChatContext chatContext) {
        List<dev.langchain4j.data.message.ChatMessage> messages = new ArrayList<>();

        // 添加系统提示
        messages.add(new dev.langchain4j.data.message.SystemMessage(
                "你是一个智能助手，能够理解和解决复杂问题。请提供准确、有用的回答。"));

        // 获取并添加历史消息
        List<MessageEntity> historyMessages = conversationDomainService.getMessageHistory(
                chatContext.getSessionId(), chatContext.getLlmModelConfig().getContextSize() - 5);

        for (MessageEntity msg : historyMessages) {
            if (msg.isUserMessage()) {
                messages.add(new dev.langchain4j.data.message.UserMessage(msg.getContent()));
            } else if (msg.isAssistantMessage()) {
                messages.add(new dev.langchain4j.data.message.AiMessage(msg.getContent()));
            }
        }

        // 添加当前用户消息
        messages.add(new dev.langchain4j.data.message.UserMessage(chatContext.getUserMessage()));

        return messages;
    }
}