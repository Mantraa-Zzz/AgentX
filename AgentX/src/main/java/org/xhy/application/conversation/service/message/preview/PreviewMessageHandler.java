package org.xhy.application.conversation.service.message.preview;

import dev.langchain4j.service.TokenStream;
import dev.langchain4j.service.tool.ToolProvider;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.dto.AgentChatResponse;
import org.xhy.application.conversation.service.handler.context.ChatContext;
import org.xhy.application.conversation.service.message.AbstractMessageHandler;
import org.xhy.application.conversation.service.message.Agent;
import org.xhy.application.conversation.service.message.StreamStateManager;
import org.xhy.application.conversation.service.message.agent.AgentToolManager;
import org.xhy.domain.conversation.constant.MessageType;
import org.xhy.domain.conversation.model.MessageEntity;
import org.xhy.domain.conversation.service.MessageDomainService;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.transport.MessageTransport;
import org.xhy.infrastructure.exception.StreamInterruptedException;

import java.util.Collections;

/** 预览消息处理器 专门用于Agent预览功能，不会保存消息到数据库 */
@Component(value = "previewMessageHandler")
public class PreviewMessageHandler extends AbstractMessageHandler {

    private final AgentToolManager agentToolManager;

    public PreviewMessageHandler(LLMServiceFactory llmServiceFactory, MessageDomainService messageDomainService,
            AgentToolManager agentToolManager) {
        super(llmServiceFactory, messageDomainService);
        this.agentToolManager = agentToolManager;
    }

    @Override
    protected ToolProvider provideTools(ChatContext chatContext) {
        return agentToolManager.createToolProvider(agentToolManager.getAvailableTools(chatContext),
                chatContext.getAgent().getToolPresetParams());
    }

    /** 预览专用的聊天处理逻辑 与正常流程的区别是不保存消息到数据库 */
    @Override
    protected <T> void processChat(Agent agent, T connection, MessageTransport<T> transport, ChatContext chatContext,
            MessageEntity userEntity, MessageEntity llmEntity) {

        String sessionId = chatContext.getSessionId();
        StreamStateManager.StreamState state = StreamStateManager.getState(sessionId);
        if (state == null)
            return;

        TokenStream tokenStream = agent.chat(chatContext.getUserMessage());

        tokenStream.onError(throwable -> {
            if (state == null || state.isCompleted())
                return;

            try {
                if (throwable instanceof StreamInterruptedException) {
                    // 处理中断情况
                    if (state.getPartialContent().length() > 0) {
                        transport.sendMessage(connection, AgentChatResponse.buildEndMessage("对话已中断", MessageType.TEXT));
                    }
                } else {
                    transport.handleError(connection, throwable);
                }
            } finally {
                state.setActive(false);
                state.setCompleted(true);
                transport.completeConnection(connection);
                StreamStateManager.removeState(sessionId);
            }
        });

        // 部分响应处理
        tokenStream.onPartialResponse(reply -> {
            if (state == null || !state.isActive() || state.isCompleted()) {
                throw new StreamInterruptedException(state != null ? state.getPartialContent().toString() : "");
            }

            try {
                state.getPartialContent().append(reply);
                transport.sendMessage(connection, AgentChatResponse.build(reply, MessageType.TEXT));
            } catch (Exception e) {
                state.setActive(false);
                throw new StreamInterruptedException(state.getPartialContent().toString());
            }
        });

        // 完整响应处理
        tokenStream.onCompleteResponse(chatResponse -> {
            if (state == null || state.isCompleted())
                return;

            try {
                if (state.isActive()) {
                    transport.sendEndMessage(connection, AgentChatResponse.buildEndMessage(MessageType.TEXT));
                }
            } finally {
                state.setCompleted(true);
                transport.completeConnection(connection);
                StreamStateManager.removeState(sessionId);
            }
        });

        // 工具执行处理
        tokenStream.onToolExecuted(toolExecution -> {
            if (state == null || !state.isActive() || state.isCompleted()) {
                throw new StreamInterruptedException(state != null ? state.getPartialContent().toString() : "");
            }

            if (state.getPartialContent().length() > 0) {
                transport.sendMessage(connection, AgentChatResponse.buildEndMessage(MessageType.TEXT));
                llmEntity.setContent(state.getPartialContent().toString());
                state.getPartialContent().setLength(0);
            }

            String message = "执行工具：" + toolExecution.request().name();
            MessageEntity toolMessage = createLlmMessage(chatContext);
            toolMessage.setMessageType(MessageType.TOOL_CALL);
            toolMessage.setContent(message);
            transport.sendMessage(connection, AgentChatResponse.buildEndMessage(message, MessageType.TOOL_CALL));
        });

        // 启动流处理
        tokenStream.start();
    }
}