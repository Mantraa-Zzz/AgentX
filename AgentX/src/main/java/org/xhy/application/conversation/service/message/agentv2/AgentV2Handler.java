package org.xhy.application.conversation.service.message.agentv2;

import dev.langchain4j.model.chat.StreamingChatLanguageModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.model.chat.response.StreamingChatResponseHandler;
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
import org.xhy.domain.conversation.model.ContextEntity;
import org.xhy.domain.conversation.model.MessageEntity;
import org.xhy.domain.conversation.service.ConversationDomainService;
import org.xhy.domain.conversation.service.ContextDomainService;
import org.xhy.domain.conversation.service.MessageDomainService;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.transport.MessageTransport;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * AgentV2处理器
 * 简化版Agent实现，支持随时中断和用户干预
 */
@Component("agentV2MessageHandler")
public class AgentV2Handler extends AbstractMessageHandler {

    private static final Logger log = LoggerFactory.getLogger(AgentV2Handler.class);
    protected static final int CONNECTION_TIMEOUT = (int) TimeUnit.MINUTES.toMillis(30);

    private final AgentLoopExecutor agentLoopExecutor;
    private final MessageAnalyzer messageAnalyzer;
    private final MessageDomainService messageDomainService;
    // 记录正在执行的会话，用于中断控制
    private final Map<String, Boolean> activeExecutions = new ConcurrentHashMap<>();

    public AgentV2Handler(
            LLMServiceFactory llmServiceFactory,
            AgentLoopExecutor agentLoopExecutor,
            MessageAnalyzer messageAnalyzer, MessageDomainService messageDomainService) {
        super(messageDomainService, llmServiceFactory);
        this.agentLoopExecutor = agentLoopExecutor;
        this.messageAnalyzer = messageAnalyzer;
        this.messageDomainService = messageDomainService;
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


        // 创建连接
        T connection = messageTransport.createConnection(CONNECTION_TIMEOUT);
        ContextEntity contextEntity = chatContext.getContextEntity();

        // 保存用户消息
        messageDomainService.saveMessageAndUpdateContext(Collections.singletonList(createUserMessage(chatContext)),contextEntity);

        // 分析用户消息
        CompletableFuture.runAsync(() -> {
            // 标记会话为活跃
            activeExecutions.put(sessionId, true);

            // 分析用户消息类型
//                Boolean analyzeResult = messageAnalyzer.analyzeMessage(chatContext);
            Boolean analyzeResult = true;

            if (analyzeResult) {
                // 普通消息，直接回复
                handleNormalMessage(chatContext,
                        connection, messageTransport);
            } else {
                // 任务消息，执行Agent循环
                handleTaskMessage(chatContext,
                        connection, messageTransport);
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
            T connection,
            MessageTransport<T> messageTransport) {

        String sessionId = chatContext.getSessionId();
        log.info("处理普通消息, 会话ID: {}", sessionId);

        StreamingChatLanguageModel streamingClient = llmServiceFactory.getStreamingClient(chatContext.getProvider(), chatContext.getModel());

        StringBuilder sb = new StringBuilder();
        MessageEntity llmMessageEntity = createLlmMessage(chatContext);
        llmMessageEntity.setCreatedAt(LocalDateTime.now());
        ChatRequest chatRequest = chatContext.prepareChatRequest().build();
        streamingClient.chat(chatRequest, new StreamingChatResponseHandler() {
            @Override
            public void onPartialResponse(String partialResponse) {
                // 检查是否应该中断
                if (!activeExecutions.getOrDefault(sessionId, true)) {
                    log.info("流式响应被中断, 会话ID: {}", sessionId);
                    throw new RuntimeException(new InterruptedException("任务被中断"));
                }
                sb.append(partialResponse);
                messageTransport.sendMessage(connection,
                        AgentChatResponse.build(partialResponse, MessageType.TEXT));
            }

            @Override
            public void onCompleteResponse(ChatResponse completeResponse) {
                messageTransport.sendEndMessage(connection,
                        AgentChatResponse.buildEndMessage(MessageType.TEXT));
                llmMessageEntity.setContent(completeResponse.aiMessage().text());
                messageDomainService.saveMessageAndUpdateContext(Collections.singletonList(llmMessageEntity),chatContext.getContextEntity());
            }

            @Override
            public void onError(Throwable error) {
                messageTransport.sendEndMessage(connection,AgentChatResponse.buildEndMessage(MessageType.TEXT));
                if (!sb.isEmpty()) {
                    llmMessageEntity.setContent(sb.toString());
                    messageDomainService.saveMessageAndUpdateContext(
                            Collections.singletonList(llmMessageEntity),
                            chatContext.getContextEntity());
                    log.info("已保存中断的部分响应, 长度: {}", sb.length());
                }

            }
        });
    }


    /**
     * 处理任务消息
     */
    private <T> void handleTaskMessage(
            ChatContext chatContext,
            T connection,
            MessageTransport<T> messageTransport) {
        MessageEntity llmMessageEntity = createLlmMessage(chatContext);

        String sessionId = chatContext.getSessionId();
        // 执行Agent循环
        agentLoopExecutor.execute(
                chatContext,
                llmMessageEntity,
                connection,
                messageTransport,
                () -> !activeExecutions.getOrDefault(sessionId, false) // 中断检查函数
        );
    }
}