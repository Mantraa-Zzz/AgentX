package org.xhy.infrastructure.converter;

import org.apache.ibatis.type.MappedTypes;
import org.xhy.domain.agent.model.AgentModelConfig;
import org.xhy.domain.llm.model.config.LLMModelConfig;

/**
 * 模型配置转换器
 */
@MappedTypes(AgentModelConfig.class)
public class AgentModelConfigConverter extends JsonToStringConverter<AgentModelConfig> {

    public AgentModelConfigConverter() {
        super(AgentModelConfig.class);
    }
} 