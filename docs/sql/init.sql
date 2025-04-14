-- 会话表，存储用户与Agent的对话会话
CREATE TABLE sessions (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    agent_id VARCHAR(36), -- 关联的Agent ID，指定该会话使用的Agent
    is_archived BOOLEAN DEFAULT FALSE,
    description TEXT,
    metadata JSONB
);

-- 消息表，存储会话中的所有消息
CREATE TABLE messages (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    token_count INTEGER,
    provider VARCHAR(50),
    model VARCHAR(50),
    metadata JSONB,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- 上下文表，管理对话上下文
CREATE TABLE context (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    active_messages JSONB,
    summary TEXT,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- 创建索引
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_created_at ON sessions(created_at);
CREATE INDEX idx_sessions_updated_at ON sessions(updated_at);

CREATE INDEX idx_messages_session_id ON messages(session_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

CREATE INDEX idx_context_session_id ON context(session_id);

-- Agent 相关表结构
CREATE TABLE agents (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    avatar VARCHAR(255),
    description TEXT,
    -- 当前编辑中的配置
    system_prompt TEXT,
    welcome_message TEXT,
    model_config JSONB,
    tools JSONB,
    knowledge_base_ids JSONB,
    -- 版本管理
    published_version VARCHAR(36), -- 当前发布的版本ID
    -- Agent状态：false-禁用，true-启用
    enabled BOOLEAN DEFAULT TRUE,
    -- Agent类型：1-聊天助手, 2-功能性Agent
    agent_type SMALLINT DEFAULT 1,
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP -- 软删除标记
);

-- Agent版本表
CREATE TABLE agent_versions (
    id VARCHAR(36) PRIMARY KEY,
    agent_id VARCHAR(36) NOT NULL,
    name VARCHAR(50) NOT NULL,
    avatar VARCHAR(255),
    description TEXT,
    version_number VARCHAR(20) NOT NULL, -- 版本号，如1.0.0
    system_prompt TEXT,
    welcome_message TEXT,
    model_config JSONB,
    tools JSONB,
    knowledge_base_ids JSONB,
    change_log TEXT, -- 版本更新日志
    agent_type SMALLINT DEFAULT 1, -- Agent类型：1-聊天助手, 2-功能性Agent
    publish_status SMALLINT DEFAULT 1, -- 1-审核中, 2-已发布, 3-拒绝, 4-已下架
    reject_reason TEXT,
    review_time TIMESTAMP,
    published_at TIMESTAMP, -- 发布时间
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP, -- 软删除标记
    FOREIGN KEY (agent_id) REFERENCES agents(id)
);

-- Agent工作区表
CREATE TABLE agent_workspace (
    id VARCHAR(36) PRIMARY KEY,
    agent_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (agent_id) REFERENCES agents(id),
    UNIQUE (agent_id, user_id)
);

-- LLM请求记录表
CREATE TABLE llm_requests (
    id VARCHAR(36) PRIMARY KEY,
    model VARCHAR(50) NOT NULL,
    temperature DOUBLE PRECISION,
    max_tokens INTEGER,
    is_stream BOOLEAN DEFAULT FALSE,
    messages JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL,
    session_id VARCHAR(36),
    user_id VARCHAR(36)
);

-- LLM响应记录表
CREATE TABLE llm_responses (
    id VARCHAR(36) PRIMARY KEY,
    request_id VARCHAR(36) NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER,
    finish_reason VARCHAR(20),
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (request_id) REFERENCES llm_requests(id)
);

-- 创建索引
CREATE INDEX idx_agents_user_id ON agents(user_id);
CREATE INDEX idx_agents_enabled ON agents(enabled);
CREATE INDEX idx_agents_agent_type ON agents(agent_type);
CREATE INDEX idx_agents_name ON agents(name);
CREATE INDEX idx_agent_versions_agent_id ON agent_versions(agent_id);
CREATE INDEX idx_agent_versions_published_at ON agent_versions(published_at);
CREATE INDEX idx_agent_versions_publish_status ON agent_versions(publish_status);
CREATE INDEX idx_agent_workspace_user_id ON agent_workspace(user_id);
CREATE INDEX idx_agent_workspace_agent_id ON agent_workspace(agent_id);

CREATE INDEX idx_sessions_agent_id ON sessions(agent_id);

CREATE INDEX idx_llm_requests_session_id ON llm_requests(session_id);
CREATE INDEX idx_llm_requests_user_id ON llm_requests(user_id);
CREATE INDEX idx_llm_requests_created_at ON llm_requests(created_at);
CREATE INDEX idx_llm_responses_request_id ON llm_responses(request_id);

-- 添加表和列的注释
COMMENT ON TABLE sessions IS '会话表，存储用户与Agent的对话会话';
COMMENT ON COLUMN sessions.agent_id IS '关联的Agent ID，指定该会话使用的Agent';
COMMENT ON COLUMN sessions.is_archived IS '会话是否被归档';
COMMENT ON COLUMN sessions.metadata IS '会话的元数据，JSON格式';

COMMENT ON TABLE messages IS '消息表，存储会话中的所有消息';
COMMENT ON COLUMN messages.role IS '消息角色：user、assistant或system';
COMMENT ON COLUMN messages.token_count IS '消息的token数量';
COMMENT ON COLUMN messages.provider IS 'LLM提供商，如OpenAI、Anthropic等';
COMMENT ON COLUMN messages.metadata IS '消息的元数据，JSON格式';

COMMENT ON TABLE context IS '上下文表，管理对话上下文';
COMMENT ON COLUMN context.active_messages IS '当前活跃的消息ID列表，JSON格式';
COMMENT ON COLUMN context.summary IS '历史消息的摘要';

COMMENT ON TABLE agents IS 'Agent表，存储AI助手的基本信息和配置';
COMMENT ON COLUMN agents.published_version IS '当前发布的版本ID';
COMMENT ON COLUMN agents.enabled IS 'Agent状态：false-禁用，true-启用';
COMMENT ON COLUMN agents.agent_type IS 'Agent类型：1-聊天助手, 2-功能性Agent';
COMMENT ON COLUMN agents.model_config IS '模型配置，JSON格式，包含模型类型、温度等参数';
COMMENT ON COLUMN agents.tools IS 'Agent可使用的工具列表，JSON格式';
COMMENT ON COLUMN agents.knowledge_base_ids IS '关联的知识库ID列表，JSON格式';
COMMENT ON COLUMN agents.deleted_at IS '软删除标记，非空表示已删除';

COMMENT ON TABLE agent_versions IS 'Agent版本表，记录Agent的各个版本';
COMMENT ON COLUMN agent_versions.version_number IS '版本号，如1.0.0';
COMMENT ON COLUMN agent_versions.change_log IS '版本更新日志';
COMMENT ON COLUMN agent_versions.publish_status IS '发布状态：1-审核中, 2-已发布, 3-拒绝, 4-已下架';
COMMENT ON COLUMN agent_versions.reject_reason IS '审核拒绝原因';
COMMENT ON COLUMN agent_versions.published_at IS '发布时间';
COMMENT ON COLUMN agent_versions.deleted_at IS '软删除标记';

COMMENT ON TABLE agent_workspace IS 'Agent工作区表，记录用户添加到工作区的Agent';

COMMENT ON TABLE llm_requests IS 'LLM请求记录表，记录发送到LLM的请求';
COMMENT ON COLUMN llm_requests.temperature IS '温度参数，控制生成文本的随机性';
COMMENT ON COLUMN llm_requests.max_tokens IS '最大生成token数';
COMMENT ON COLUMN llm_requests.is_stream IS '是否为流式响应';
COMMENT ON COLUMN llm_requests.messages IS '发送的消息列表，JSON格式';

COMMENT ON TABLE llm_responses IS 'LLM响应记录表，记录LLM的响应';
COMMENT ON COLUMN llm_responses.finish_reason IS '结束原因：stop、length、content_filter等'; 