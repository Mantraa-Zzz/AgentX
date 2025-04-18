package org.xhy.application.conversation.service.message.agentv2.analyzer;

import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatLanguageModel;
import dev.langchain4j.model.chat.request.ChatRequest;
import dev.langchain4j.model.chat.response.ChatResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.xhy.application.conversation.service.handler.content.ChatContext;
import org.xhy.application.conversation.service.message.agent.template.AgentPromptTemplates;
import org.xhy.application.conversation.service.message.agentv2.analysis.dto.AnalysisResultDTO;
import org.xhy.infrastructure.llm.LLMServiceFactory;
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
    public AnalysisResultDTO analyzeMessage(ChatContext chatContext) {
        String userMessage = chatContext.getUserMessage();
        log.info("分析用户消息: {}", userMessage);

        try {
            // 获取聊天模型
            ChatLanguageModel model = llmServiceFactory.getStrandClient(
                    chatContext.getProvider(),
                    chatContext.getModel());

            // 构建请求
            List<ChatMessage> messages = new ArrayList<>();
            messages.add(new SystemMessage(AgentPromptTemplates.getAnalyserMessagePrompt(userMessage)));

            // 构建请求对象
            ChatRequest request = ChatRequest.builder()
                    .messages(messages)
                    .build();

            // 调用模型分析
            ChatResponse response = model.chat(request);
            String analysisResponse = response.aiMessage().text();

            // 解析结果
            AnalysisResultDTO result = ModelResponseToJsonUtils.toJson(
                    analysisResponse, AnalysisResultDTO.class);

            if (result != null) {
                log.info("消息分析结果: isQuestion={}", result.isQuestion());
                return result;
            }
        } catch (Exception e) {
            log.error("解析消息分析结果出错", e);
        }

        // 默认作为任务消息处理
        return new AnalysisResultDTO(false, "");
    }
}