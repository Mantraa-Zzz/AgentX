# AgentX 数据库 SQL 文件

本目录包含 AgentX 项目的数据库 SQL 文件，用于初始化 PostgreSQL 数据库。

## 文件说明

- `init.sql`: 主要的数据库初始化文件，包含所有表结构和索引定义

## 表结构说明

### sessions 表

存储对话会话信息。

```sql
CREATE TABLE sessions (
    id VARCHAR(36) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_archived BOOLEAN DEFAULT FALSE,
    metadata JSON
);
```

### messages 表

存储对话消息内容。

```sql
CREATE TABLE messages (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    token_count INTEGER,
    provider VARCHAR(50),
    model VARCHAR(50),
    metadata JSON,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);
```

### context 表

存储会话上下文信息。

```sql
CREATE TABLE context (
    id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    active_messages JSON,
    summary TEXT,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);
```

## 使用方法

这些 SQL 文件会被 `script` 目录下的脚本自动导入到 PostgreSQL 数据库中。请参考项目根目录下的 `script/README.md` 文件了解如何使用这些脚本启动数据库并初始化表结构。 