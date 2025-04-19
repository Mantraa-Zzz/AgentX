package org.xhy.application.conversation.service.message.agentv2.analyzer;

import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import dev.langchain4j.service.AiServices;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.service.handler.content.ChatContext;
import org.xhy.application.conversation.service.message.agent.analysis.dto.AnalyzerMessageDTO;
import org.xhy.application.conversation.service.message.agent.template.AgentPromptTemplates;
import org.xhy.application.conversation.service.message.agentv2.analysis.dto.AnalysisResultDTO;
import org.xhy.application.conversation.service.message.agentv2.dto.AnalyzerMessage;
import org.xhy.infrastructure.llm.LLMServiceFactory;
import org.xhy.infrastructure.utils.JsonUtils;
import org.xhy.infrastructure.utils.ModelResponseToJsonUtils;

import java.util.ArrayList;
import java.util.List;

/**
 * 消息分析器
 * 分析用户输入的消息类型（普通消息或任务消息）
 * 复用现有的分析逻辑
 */
@Component
public class MessageAnalyzer {

    private static final Logger log = LoggerFactory.getLogger(MessageAnalyzer.class);

    private final LLMServiceFactory llmServiceFactory;

    public MessageAnalyzer(LLMServiceFactory llmServiceFactory) {
        this.llmServiceFactory = llmServiceFactory;
    }

    /**
     * 分析用户消息类型
     * 返回分析结果，包含消息类型和可能的直接回复
     */
    public Boolean analyzeMessage(ChatContext chatContext) {
        String userMessage = chatContext.getUserMessage();
        log.info("分析用户消息: {}", userMessage);

        try {
            // 获取聊天模型
            ChatLanguageModel model = llmServiceFactory.getStrandClient(
                    chatContext.getProvider(),
                    chatContext.getModel());

            ChatRequest request = chatContext.prepareChatRequest().build();
            request.messages().add(new SystemMessage(AgentPromptTemplates.getAnalyserMessagePrompt()));
            // 调用模型分析
            ChatResponse response = model.chat(request);

            String text = response.aiMessage().text();
            return Boolean.valueOf(text.trim());

        } catch (Exception e) {
            log.error("解析消息分析结果出错", e);
        }
        return false;
    }
}