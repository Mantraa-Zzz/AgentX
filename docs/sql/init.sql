-- AgentX初始化数据库脚本 - PostgreSQL版本

-- 会话表，存储用户与Agent的对话会话
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    agent_id VARCHAR(36) NOT NULL,
    description TEXT,
    is_archived BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- 消息表，存储会话中的所有消息
CREATE TABLE IF NOT EXISTS messages (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    token_count INTEGER DEFAULT 0,
    provider VARCHAR(50),
    model VARCHAR(50),
    metadata TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- 上下文表，管理对话上下文
CREATE TABLE IF NOT EXISTS context (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    active_messages JSONB,
    summary TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- Agent 相关表结构
CREATE TABLE IF NOT EXISTS agents (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    avatar VARCHAR(255),
    description TEXT,
    system_prompt TEXT,
    welcome_message TEXT,
    model_config JSONB,
    tools JSONB,
    knowledge_base_ids JSONB,
    published_version VARCHAR(36),
    enabled BOOLEAN DEFAULT TRUE,
    agent_type SMALLINT DEFAULT 1,
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- Agent版本表
CREATE TABLE IF NOT EXISTS agent_versions (
    id VARCHAR(36) PRIMARY KEY,
    agent_id VARCHAR(36) NOT NULL,
    name VARCHAR(100) NOT NULL,
    avatar VARCHAR(255),
    description TEXT,
    version_number VARCHAR(20) NOT NULL,
    system_prompt TEXT,
    welcome_message TEXT,
    model_config JSONB,
    tools JSONB,
    knowledge_base_ids JSONB,
    change_log TEXT,
    agent_type SMALLINT DEFAULT 1,
    publish_status SMALLINT DEFAULT 1,
    reject_reason TEXT,
    review_time TIMESTAMP,
    published_at TIMESTAMP,
    user_id VARCHAR(36) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- Agent工作区表
CREATE TABLE IF NOT EXISTS agent_workspace (
    id VARCHAR(36) PRIMARY KEY,
    agent_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    model_id VARCHAR(36),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP,
    UNIQUE (agent_id, user_id)
);

-- 服务提供商表
CREATE TABLE IF NOT EXISTS providers (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    protocol VARCHAR(20),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    config TEXT,
    is_official BOOLEAN DEFAULT FALSE,
    status BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- 模型表
CREATE TABLE IF NOT EXISTS models (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    provider_id VARCHAR(36) NOT NULL,
    model_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_official BOOLEAN DEFAULT FALSE,
    type VARCHAR(20),
    config JSONB,
    status BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    deleted_at TIMESTAMP
);

-- 创建索引
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_created_at ON sessions(created_at);
CREATE INDEX idx_sessions_updated_at ON sessions(updated_at);
CREATE INDEX idx_sessions_agent_id ON sessions(agent_id);
CREATE INDEX idx_messages_session_id ON messages(session_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_context_session_id ON context(session_id);
CREATE INDEX idx_agents_user_id ON agents(user_id);
CREATE INDEX idx_agents_enabled ON agents(enabled);
CREATE INDEX idx_agents_agent_type ON agents(agent_type);
CREATE INDEX idx_agents_name ON agents(name);
CREATE INDEX idx_agent_versions_agent_id ON agent_versions(agent_id);
CREATE INDEX idx_agent_versions_published_at ON agent_versions(published_at);
CREATE INDEX idx_agent_versions_publish_status ON agent_versions(publish_status);
CREATE INDEX idx_agent_workspace_user_id ON agent_workspace(user_id);
CREATE INDEX idx_agent_workspace_agent_id ON agent_workspace(agent_id);
CREATE INDEX idx_providers_user_id ON providers(user_id);
CREATE INDEX idx_models_provider_id ON models(provider_id);
CREATE INDEX idx_models_user_id ON models(user_id);

-- 添加表和列的注释
COMMENT ON TABLE sessions IS '会话表，存储用户与Agent的对话会话';
COMMENT ON COLUMN sessions.agent_id IS '关联的Agent ID，指定该会话使用的Agent';
COMMENT ON COLUMN sessions.is_archived IS '会话是否被归档';
COMMENT ON COLUMN sessions.metadata IS '会话的元数据，JSON格式';

COMMENT ON TABLE messages IS '消息表，存储会话中的所有消息';
COMMENT ON COLUMN messages.role IS '消息角色：user、assistant或system';
COMMENT ON COLUMN messages.token_count IS '消息的token数量';
COMMENT ON COLUMN messages.provider IS 'LLM提供商，如OpenAI、Anthropic等';
COMMENT ON COLUMN messages.metadata IS '消息的元数据';

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
COMMENT ON COLUMN agent_workspace.model_id IS '关联的模型ID';

COMMENT ON TABLE providers IS '服务提供商表，记录LLM服务提供商信息';
COMMENT ON COLUMN providers.protocol IS '协议类型';
COMMENT ON COLUMN providers.config IS '提供商配置，包含API密钥等信息';
COMMENT ON COLUMN providers.is_official IS '是否为官方提供商';
COMMENT ON COLUMN providers.status IS '提供商状态：false-禁用，true-启用';

COMMENT ON TABLE models IS '模型表，记录可用的LLM模型信息';
COMMENT ON COLUMN models.provider_id IS '关联的服务提供商ID';
COMMENT ON COLUMN models.model_id IS '模型原始ID，如gpt-4等';
COMMENT ON COLUMN models.type IS '模型类型';
COMMENT ON COLUMN models.config IS '模型配置，JSON格式';
COMMENT ON COLUMN models.is_official IS '是否为官方模型';
COMMENT ON COLUMN models.status IS '模型状态：false-禁用，true-启用';
