#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否为自动模式
AUTO_MODE=false
for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_MODE=true
            ;;
        --host=*)
            AUTO_DB_HOST="${arg#*=}"
            ;;
        --port=*)
            AUTO_DB_PORT="${arg#*=}"
            ;;
        --dbname=*)
            AUTO_DB_NAME="${arg#*=}"
            ;;
        --username=*)
            AUTO_DB_USERNAME="${arg#*=}"
            ;;
    esac
done

if [ "$AUTO_MODE" = false ]; then
    echo -e "${BLUE}🗄️  AgentX 外部数据库初始化脚本${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo
fi

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 检查psql是否安装
if ! command -v psql &> /dev/null; then
    echo -e "${RED}错误: PostgreSQL客户端(psql)未安装${NC}"
    if [ "$AUTO_MODE" = false ]; then
        echo -e "${YELLOW}请先安装PostgreSQL客户端:${NC}"
        echo "  Ubuntu/Debian: sudo apt install postgresql-client"
        echo "  CentOS/RHEL: sudo yum install postgresql"
        echo "  macOS: brew install postgresql"
    fi
    exit 1
fi

# 获取数据库连接信息
if [ "$AUTO_MODE" = true ]; then
    # 自动模式使用传入的参数
    DB_HOST=${AUTO_DB_HOST:-localhost}
    DB_PORT=${AUTO_DB_PORT:-5432}
    ADMIN_USER="postgres"
    DB_NAME=${AUTO_DB_NAME:-agentx}
    DB_USER=${AUTO_DB_USERNAME:-agentx_user}
    
    # 尝试从环境变量或文件获取管理员密码
    if [ -f ~/.postgres_admin ]; then
        source ~/.postgres_admin
        ADMIN_PASSWORD=$POSTGRES_ADMIN_PASSWORD
    else
        echo -e "${RED}❌ 自动模式需要管理员密码，请先运行 install-postgres.sh${NC}"
        exit 1
    fi
    
    # 生成随机密码
    DB_PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "agentx$(date +%s)")
    
    echo -e "${BLUE}🔧 自动配置数据库: $DB_HOST:$DB_PORT/$DB_NAME${NC}"
else
    echo -e "${YELLOW}请输入数据库连接信息:${NC}"
    
    read -p "数据库主机地址 [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

read -p "数据库端口 [5432]: " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "PostgreSQL管理员用户名 [postgres]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-postgres}

read -s -p "PostgreSQL管理员密码: " ADMIN_PASSWORD
echo

read -p "AgentX数据库名称 [agentx]: " DB_NAME
DB_NAME=${DB_NAME:-agentx}

read -p "AgentX数据库用户名 [agentx_user]: " DB_USER
DB_USER=${DB_USER:-agentx_user}

read -s -p "AgentX数据库用户密码: " DB_PASSWORD
echo

echo
echo -e "${BLUE}📋 配置总结:${NC}"
echo "  数据库主机: $DB_HOST:$DB_PORT"
echo "  管理员用户: $ADMIN_USER"
echo "  数据库名称: $DB_NAME"
echo "  应用用户: $DB_USER"
echo

# 确认操作
read -p "确认创建数据库和用户? [Y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}操作已取消${NC}"
    exit 0
fi

# 测试管理员连接
echo -e "${YELLOW}⏳ 测试数据库连接...${NC}"
export PGPASSWORD=$ADMIN_PASSWORD
if ! psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${RED}❌ 无法连接到数据库，请检查连接信息${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 数据库连接成功${NC}"

# 检查数据库是否已存在
echo -e "${YELLOW}🔍 检查数据库状态...${NC}"
DB_EXISTS=$(psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';" 2>/dev/null)

if [ "$DB_EXISTS" = "1" ]; then
    echo -e "${YELLOW}⚠️  数据库 '$DB_NAME' 已存在${NC}"
    read -p "是否删除现有数据库并重新创建? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}删除现有数据库...${NC}"
        psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" > /dev/null 2>&1
        psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "DROP USER IF EXISTS $DB_USER;" > /dev/null 2>&1
    else
        echo -e "${GREEN}跳过数据库创建，使用现有数据库${NC}"
        USER_EXISTS=$(psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -tAc "SELECT 1 FROM pg_user WHERE usename='$DB_USER';" 2>/dev/null)
        if [ "$USER_EXISTS" != "1" ]; then
            echo -e "${YELLOW}创建应用用户...${NC}"
            psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
            psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
        fi
        echo -e "${GREEN}✅ 数据库配置完成${NC}"
        exit 0
    fi
fi

# 创建数据库和用户
echo -e "${YELLOW}📦 创建数据库和用户...${NC}"

# 创建用户
psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null

# 创建数据库
psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING 'UTF8';" 2>/dev/null

# 授权
psql -h $DB_HOST -p $DB_PORT -U $ADMIN_USER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null

# 安装pgvector扩展（如果支持）
echo -e "${YELLOW}🔧 安装PostgreSQL扩展...${NC}"
export PGPASSWORD=$DB_PASSWORD
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || echo -e "${YELLOW}⚠️  pgvector扩展安装失败，如需向量功能请手动安装${NC}"

# 执行初始化SQL脚本
echo -e "${YELLOW}📜 执行数据库初始化脚本...${NC}"
if [ -f "$PROJECT_ROOT/docs/sql/01_init.sql" ]; then
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$PROJECT_ROOT/docs/sql/01_init.sql" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 初始化脚本执行成功${NC}"
    else
        echo -e "${YELLOW}⚠️  初始化脚本执行可能有问题，请检查${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  初始化脚本不存在: $PROJECT_ROOT/docs/sql/01_init.sql${NC}"
fi

# 测试应用用户连接
echo -e "${YELLOW}🧪 测试应用用户连接...${NC}"
if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 应用用户连接成功${NC}"
else
    echo -e "${RED}❌ 应用用户连接失败${NC}"
    exit 1
fi

# 生成环境变量文件
echo -e "${YELLOW}📝 生成环境变量配置...${NC}"
cat > "$PROJECT_ROOT/.env.database" << EOF
# AgentX 数据库配置
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USER
DB_PASSWORD=$DB_PASSWORD

# 使用示例:
# 在docker-compose中引用: \${DB_HOST}
# 或者执行: source .env.database
EOF

echo -e "${GREEN}✅ 环境变量配置已保存到: $PROJECT_ROOT/.env.database${NC}"

echo
echo -e "${GREEN}"
echo "🎉 ================================================ 🎉"
echo "           🗄️  数据库初始化完成! 🗄️               "
echo "🎉 ================================================ 🎉"
echo -e "${NC}"

echo -e "${BLUE}📋 数据库信息:${NC}"
echo "  - 主机地址: $DB_HOST:$DB_PORT"
echo "  - 数据库名: $DB_NAME"
echo "  - 用户名: $DB_USER"
echo "  - 密码: [已设置]"
echo

echo -e "${BLUE}📱 下一步操作:${NC}"
echo "  1. 使用生产模式部署: ./bin/deploy.sh (选择选项3)"
echo "  2. 或手动设置环境变量:"
echo "     export DB_HOST=$DB_HOST"
echo "     export DB_PORT=$DB_PORT"
echo "     export DB_NAME=$DB_NAME"
echo "     export DB_USERNAME=$DB_USER"
echo "     export DB_PASSWORD='$DB_PASSWORD'"
echo "  3. 或加载环境变量文件: source .env.database"

echo
echo -e "${YELLOW}💡 提示:${NC}"
echo "  - 请妥善保管数据库密码"
echo "  - 建议定期备份数据库"
echo "  - 生产环境请使用强密码"

echo
echo -e "${GREEN}✅ 数据库初始化完成！${NC}"