#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 获取项目根目录的绝对路径
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_DIR="$PROJECT_ROOT/docs/sql"

# 参数设置
CONTAINER_NAME="agentx-postgres"
DB_NAME="agentx"
DB_USER="postgres"
DB_PASSWORD="postgres"
DB_PORT="5432"
HOST_PORT="5432"
INIT_SQL="$SQL_DIR/init.sql"

echo -e "${GREEN}AgentX PostgreSQL 数据库初始化脚本${NC}"
echo "==============================================="
echo "容器名称: $CONTAINER_NAME"
echo "数据库名称: $DB_NAME"
echo "数据库用户: $DB_USER"
echo "数据库端口: $DB_PORT"
echo "主机映射端口: $HOST_PORT"
echo "SQL文件路径: $INIT_SQL"
echo "==============================================="

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查 SQL 文件是否存在
if [ ! -f "$INIT_SQL" ]; then
    echo -e "${RED}错误: 初始化 SQL 文件 '$INIT_SQL' 不存在${NC}"
    exit 1
fi

# 检查容器是否已存在
if docker ps -a | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}警告: 容器 '$CONTAINER_NAME' 已存在${NC}"
    read -p "是否停止并删除已有容器? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "停止容器..."
        docker stop "$CONTAINER_NAME" > /dev/null
        echo "删除容器..."
        docker rm "$CONTAINER_NAME" > /dev/null
    else
        echo "操作取消"
        exit 0
    fi
fi

# 检查端口是否已被占用
if lsof -Pi :$HOST_PORT -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}警告: 端口 $HOST_PORT 已被占用${NC}"
    read -p "是否使用不同的端口? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "请输入新的端口号: " HOST_PORT
    else
        echo "操作取消"
        exit 0
    fi
fi

echo -e "${GREEN}启动 PostgreSQL 容器...${NC}"
docker run --name "$CONTAINER_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -e POSTGRES_DB="$DB_NAME" \
    -p "$HOST_PORT:$DB_PORT" \
    -v "$SQL_DIR:/docker-entrypoint-initdb.d" \
    -d ankane/pgvector:latest

# 检查容器是否成功启动
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: 容器启动失败${NC}"
    exit 1
fi

echo -e "${GREEN}等待 PostgreSQL 启动...${NC}"
sleep 5

# 确认 PostgreSQL 是否已准备好接受连接
RETRIES=10
until docker exec "$CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1 || [ $RETRIES -eq 0 ]; do
    echo "等待 PostgreSQL 启动中，剩余尝试次数: $RETRIES"
    RETRIES=$((RETRIES-1))
    sleep 3
done

if [ $RETRIES -eq 0 ]; then
    echo -e "${RED}错误: PostgreSQL 启动超时${NC}"
    exit 1
fi

echo -e "${GREEN}PostgreSQL 容器已成功启动！${NC}"
echo "容器名称: $CONTAINER_NAME"
echo "连接信息:"
echo "  主机: localhost"
echo "  端口: $HOST_PORT"
echo "  用户: $DB_USER"
echo "  密码: $DB_PASSWORD"
echo "  数据库: $DB_NAME"
echo "  连接URL: jdbc:postgresql://localhost:$HOST_PORT/$DB_NAME"
echo 
echo "你可以使用以下命令连接到数据库:"
echo "  docker exec -it $CONTAINER_NAME psql -U $DB_USER -d $DB_NAME"
echo
echo -e "${GREEN}数据库初始化完成！${NC}" 