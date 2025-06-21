#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 获取项目根目录的绝对路径
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}"
echo "   ▄▄▄        ▄████  ▓█████  ███▄    █ ▄▄▄█████▓▒██   ██▒"
echo "  ▒████▄     ██▒ ▀█▒ ▓█   ▀  ██ ▀█   █ ▓  ██▒ ▓▒▒▒ █ █ ▒░"
echo "  ▒██  ▀█▄  ▒██░▄▄▄░ ▒███   ▓██  ▀█ ██▒▒ ▓██░ ▒░░░  █   ░"
echo "  ░██▄▄▄▄██ ░▓█  ██▓ ▒▓█  ▄ ▓██▒  ▐▌██▒░ ▓██▓ ░  ░ █ █ ▒ "
echo "   ▓█   ▓██▒░▒▓███▀▒ ░▒████▒▒██░   ▓██░  ▒██▒ ░ ▒██▒ ▒██▒"
echo -e "   ▒▒   ▓▒█░ ░▒   ▒  ░░ ▒░ ░░ ▒░   ▒ ▒   ▒ ░░   ▒▒ ░ ░▓ ░ ${NC}"
echo -e "${GREEN}              智能AI助手平台 - 智能部署脚本${NC}"
echo -e "${BLUE}========================================================${NC}"
echo

# 显示部署选项
echo -e "${CYAN}🚀 请选择部署模式:${NC}"
echo
echo "  1) 🔥 完整模式 (Full) - 包含所有服务和组件"
echo "     ├── PostgreSQL 数据库容器"
echo "     ├── API Gateway 高可用网关"
echo "     ├── AgentX 后端服务"
echo "     ├── AgentX 前端服务"
echo "     └── MCP 网关服务"
echo
echo "  2) ⚡ 简化模式 (Simple) - 轻量级部署"
echo "     ├── PostgreSQL 数据库容器"
echo "     ├── AgentX 后端服务"
echo "     ├── AgentX 前端服务"
echo "     └── MCP 网关服务"
echo "     (无 API Gateway)"
echo
echo "  3) 🏭 生产模式 (Production) - 外部数据库"
echo "     ├── 自动安装 PostgreSQL 数据库"
echo "     ├── AgentX 后端服务"
echo "     ├── AgentX 前端服务"
echo "     └── MCP 网关服务"
echo "     (可选择自动安装或使用现有数据库)"
echo
echo "  4) 🧪 开发模式 (Development) - 带热重载"
echo "     ├── PostgreSQL 数据库容器"
echo "     ├── AgentX 后端服务 (热重载)"
echo "     ├── AgentX 前端服务 (热重载)"
echo "     └── MCP 网关服务"
echo
echo "  5) 🛠️  自定义模式 (Custom) - 按需选择组件"
echo

# 读取用户选择
read -p "请输入选择 [1-5]: " -n 1 -r DEPLOY_MODE
echo
echo

case $DEPLOY_MODE in
    1)
        echo -e "${GREEN}✅ 选择: 完整模式部署${NC}"
        COMPOSE_FILE="docker-compose.yml"
        USE_EXTERNAL_DB=false
        USE_API_GATEWAY=true
        USE_DEV_MODE=false
        ;;
    2)
        echo -e "${GREEN}✅ 选择: 简化模式部署${NC}"
        COMPOSE_FILE="docker-compose.simple.yml"
        USE_EXTERNAL_DB=false
        USE_API_GATEWAY=false
        USE_DEV_MODE=false
        ;;
    3)
        echo -e "${GREEN}✅ 选择: 生产模式部署${NC}"
        COMPOSE_FILE="docker-compose.prod.yml"
        USE_EXTERNAL_DB=true
        USE_API_GATEWAY=false
        USE_DEV_MODE=false
        ;;
    4)
        echo -e "${GREEN}✅ 选择: 开发模式部署${NC}"
        COMPOSE_FILE="docker-compose.dev.yml"
        USE_EXTERNAL_DB=false
        USE_API_GATEWAY=false
        USE_DEV_MODE=true
        ;;
    5)
        echo -e "${GREEN}✅ 选择: 自定义模式部署${NC}"
        # 自定义选择逻辑
        echo -e "${YELLOW}请选择需要的组件:${NC}"
        
        read -p "是否使用外部数据库? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USE_EXTERNAL_DB=true
        else
            USE_EXTERNAL_DB=false
        fi
        
        read -p "是否包含API网关? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USE_API_GATEWAY=true
        else
            USE_API_GATEWAY=false
        fi
        
        read -p "是否启用开发模式(热重载)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            USE_DEV_MODE=true
        else
            USE_DEV_MODE=false
        fi
        
        COMPOSE_FILE="docker-compose.custom.yml"
        ;;
    *)
        echo -e "${RED}无效选择，退出${NC}"
        exit 1
        ;;
esac

echo
echo -e "${BLUE}📋 部署配置总结:${NC}"
echo "  - 使用配置文件: $COMPOSE_FILE"
echo "  - 外部数据库: $([ "$USE_EXTERNAL_DB" = true ] && echo "是" || echo "否")"
echo "  - API网关: $([ "$USE_API_GATEWAY" = true ] && echo "是" || echo "否")"
echo "  - 开发模式: $([ "$USE_DEV_MODE" = true ] && echo "是" || echo "否")"
echo

# 如果使用外部数据库，检查配置
if [ "$USE_EXTERNAL_DB" = true ]; then
    echo -e "${YELLOW}🔧 外部数据库配置:${NC}"
    echo
    echo "请选择数据库安装方式:"
    echo "  1) 🚀 自动安装 PostgreSQL (推荐)"
    echo "  2) 🔧 使用现有数据库"
    echo "  3) 📋 手动配置数据库"
    echo
    
    read -p "请选择 [1-3]: " -n 1 -r DB_SETUP_MODE
    echo
    echo
    
    case $DB_SETUP_MODE in
        1)
            echo -e "${GREEN}✅ 选择: 自动安装 PostgreSQL${NC}"
            
            # 检查是否已安装PostgreSQL
            if command -v psql &> /dev/null && systemctl is-active postgresql &> /dev/null 2>&1; then
                echo -e "${YELLOW}⚠️  检测到已安装的 PostgreSQL${NC}"
                read -p "是否重新配置? [y/N]: " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${BLUE}开始重新配置 PostgreSQL...${NC}"
                    "$PROJECT_ROOT/bin/install-postgres.sh"
                else
                    echo -e "${GREEN}使用现有 PostgreSQL 安装${NC}"
                fi
            else
                echo -e "${BLUE}开始自动安装 PostgreSQL...${NC}"
                "$PROJECT_ROOT/bin/install-postgres.sh"
                
                if [ $? -ne 0 ]; then
                    echo -e "${RED}❌ PostgreSQL 安装失败${NC}"
                    read -p "是否继续使用容器数据库? [Y/n]: " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                        echo -e "${YELLOW}切换到容器数据库模式${NC}"
                        USE_EXTERNAL_DB=false
                    else
                        exit 1
                    fi
                fi
            fi
            
            # 如果成功安装，自动配置数据库连接
            if [ "$USE_EXTERNAL_DB" = true ]; then
                echo -e "${BLUE}🔧 自动配置数据库连接...${NC}"
                DB_HOST="localhost"
                DB_PORT="5432"
                DB_NAME="agentx"
                DB_USERNAME="agentx_user"
                
                # 尝试从保存的文件读取密码
                if [ -f ~/.postgres_admin ]; then
                    source ~/.postgres_admin
                    echo -e "${GREEN}✅ 已加载管理员密码${NC}"
                fi
                
                # 运行数据库初始化脚本
                echo -e "${BLUE}🗄️  初始化应用数据库...${NC}"
                "$PROJECT_ROOT/bin/setup-external-db.sh" --auto --host="$DB_HOST" --port="$DB_PORT" --dbname="$DB_NAME" --username="$DB_USERNAME"
                
                # 从生成的配置文件读取连接信息
                if [ -f "$PROJECT_ROOT/.env.database" ]; then
                    source "$PROJECT_ROOT/.env.database"
                    echo -e "${GREEN}✅ 数据库配置加载成功${NC}"
                fi
            fi
            ;;
        2)
            echo -e "${GREEN}✅ 选择: 使用现有数据库${NC}"
            
            # 运行数据库初始化脚本
            echo -e "${BLUE}🗄️  配置现有数据库...${NC}"
            "$PROJECT_ROOT/bin/setup-external-db.sh"
            
            # 从生成的配置文件读取连接信息
            if [ -f "$PROJECT_ROOT/.env.database" ]; then
                source "$PROJECT_ROOT/.env.database"
                echo -e "${GREEN}✅ 数据库配置加载成功${NC}"
            else
                echo -e "${RED}❌ 数据库配置失败${NC}"
                exit 1
            fi
            ;;
        3)
            echo -e "${GREEN}✅ 选择: 手动配置数据库${NC}"
            
            # 手动输入数据库信息
            if [ -z "$DB_HOST" ]; then
                read -p "数据库主机地址 [localhost]: " DB_HOST
                DB_HOST=${DB_HOST:-localhost}
            fi
            
            if [ -z "$DB_PORT" ]; then
                read -p "数据库端口 [5432]: " DB_PORT
                DB_PORT=${DB_PORT:-5432}
            fi
            
            if [ -z "$DB_NAME" ]; then
                read -p "数据库名称 [agentx]: " DB_NAME
                DB_NAME=${DB_NAME:-agentx}
            fi
            
            if [ -z "$DB_USERNAME" ]; then
                read -p "数据库用户名: " DB_USERNAME
            fi
            
            if [ -z "$DB_PASSWORD" ]; then
                read -s -p "数据库密码: " DB_PASSWORD
                echo
            fi
            
            # 测试数据库连接
            echo -e "${YELLOW}正在测试数据库连接...${NC}"
            if command -v psql &> /dev/null; then
                PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ 数据库连接成功${NC}"
                else
                    echo -e "${RED}❌ 数据库连接失败，请检查配置${NC}"
                    read -p "是否继续部署? [y/N]: " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        exit 1
                    fi
                fi
            else
                echo -e "${YELLOW}⚠️  无法测试数据库连接（未安装psql），继续部署${NC}"
            fi
            ;;
        *)
            echo -e "${RED}无效选择，使用默认配置${NC}"
            DB_HOST="localhost"
            DB_PORT="5432"
            DB_NAME="agentx"
            ;;
    esac
fi

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 生成对应的docker-compose文件
echo -e "${BLUE}📝 生成配置文件...${NC}"

# 生成配置文件的函数
generate_compose_file() {
    cat > "$COMPOSE_FILE" << EOF
version: "3.8"

services:
EOF

    # 添加数据库服务（如果不使用外部数据库）
    if [ "$USE_EXTERNAL_DB" = false ]; then
        cat >> "$COMPOSE_FILE" << EOF
  # AgentX PostgreSQL数据库
  postgres:
    image: ankane/pgvector:latest
    container_name: agentx-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=agentx
    ports:
      - "5432:5432"
    volumes:
      - ./docs/sql:/docker-entrypoint-initdb.d
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d agentx"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - agentx-network

EOF
    fi

    # 添加API网关服务（如果需要）
    if [ "$USE_API_GATEWAY" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
  # API网关 PostgreSQL数据库
  gateway-postgres:
    image: postgres:15-alpine
    container_name: api-gateway-postgres
    environment:
      - POSTGRES_DB=api_gateway
      - POSTGRES_USER=gateway_user
      - POSTGRES_PASSWORD=gateway_pass
    ports:
      - "5433:5432"
    volumes:
      - ./API-Premium-Gateway/docs/sql:/docker-entrypoint-initdb.d:ro
      - gateway-postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gateway_user -d api_gateway"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - agentx-network

  # API网关服务
  api-gateway:
    build:
      context: ./API-Premium-Gateway
      dockerfile: Dockerfile
    container_name: agentx-api-gateway
    ports:
      - "8081:8081"
    environment:
      - SPRING_PROFILES_ACTIVE=docker
      - SPRING_DATASOURCE_URL=jdbc:postgresql://gateway-postgres:5432/api_gateway
      - SPRING_DATASOURCE_USERNAME=gateway_user
      - SPRING_DATASOURCE_PASSWORD=gateway_pass
    depends_on:
      gateway-postgres:
        condition: service_healthy
    volumes:
      - ./logs/gateway:/app/logs
    networks:
      - agentx-network
    restart: unless-stopped

EOF
    fi

    # 添加后端服务
    cat >> "$COMPOSE_FILE" << EOF
  # AgentX后端服务
  agentx-backend:
    build:
      context: ./AgentX
      dockerfile: $([ "$USE_DEV_MODE" = true ] && echo "Dockerfile.dev" || echo "Dockerfile")
    container_name: agentx-backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=$([ "$USE_DEV_MODE" = true ] && echo "dev" || echo "prod")
EOF

    # 数据库连接配置
    if [ "$USE_EXTERNAL_DB" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
      - DB_HOST=${DB_HOST}
      - DB_PORT=${DB_PORT}
      - DB_NAME=${DB_NAME}
      - DB_USERNAME=${DB_USERNAME}
      - DB_PASSWORD=${DB_PASSWORD}
EOF
    else
        cat >> "$COMPOSE_FILE" << EOF
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=agentx
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgres
EOF
    fi

    # 继续后端服务配置
    cat >> "$COMPOSE_FILE" << EOF
      - MCP_GATEWAY_URL=http://mcp-gateway:8080
EOF

    if [ "$USE_API_GATEWAY" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
      - HIGH_AVAILABILITY_GATEWAY_URL=http://api-gateway:8081
EOF
    fi

    cat >> "$COMPOSE_FILE" << EOF
    depends_on:
EOF

    if [ "$USE_EXTERNAL_DB" = false ]; then
        cat >> "$COMPOSE_FILE" << EOF
      postgres:
        condition: service_healthy
EOF
    fi

    if [ "$USE_API_GATEWAY" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
      api-gateway:
        condition: service_started
EOF
    fi

    cat >> "$COMPOSE_FILE" << EOF
      mcp-gateway:
        condition: service_started
    volumes:
      - ./logs/backend:/app/logs
    networks:
      - agentx-network
    restart: unless-stopped

  # AgentX前端服务
  agentx-frontend:
    build:
      context: ./agentx-frontend-plus
      dockerfile: $([ "$USE_DEV_MODE" = true ] && echo "Dockerfile.dev" || echo "Dockerfile")
    container_name: agentx-frontend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=$([ "$USE_DEV_MODE" = true ] && echo "development" || echo "production")
      - NEXT_PUBLIC_API_URL=http://localhost:8080
EOF

    if [ "$USE_API_GATEWAY" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
      - NEXT_PUBLIC_GATEWAY_URL=http://localhost:8081
EOF
    fi

    cat >> "$COMPOSE_FILE" << EOF
    depends_on:
      - agentx-backend
    networks:
      - agentx-network
    restart: unless-stopped

  # MCP网关服务
  mcp-gateway:
    image: ghcr.io/lucky-aeon/mcp-gateway:latest
    container_name: agentx-mcp-gateway
    ports:
      - "8005:8080"
    networks:
      - agentx-network
    restart: unless-stopped

EOF

    # 添加volumes（如果使用容器数据库）
    if [ "$USE_EXTERNAL_DB" = false ] || [ "$USE_API_GATEWAY" = true ]; then
        cat >> "$COMPOSE_FILE" << EOF
volumes:
EOF
        if [ "$USE_EXTERNAL_DB" = false ]; then
            cat >> "$COMPOSE_FILE" << EOF
  postgres-data:
    name: agentx-postgres-data
EOF
        fi
        if [ "$USE_API_GATEWAY" = true ]; then
            cat >> "$COMPOSE_FILE" << EOF
  gateway-postgres-data:
    name: api-gateway-postgres-data
EOF
        fi
        echo >> "$COMPOSE_FILE"
    fi

    # 添加networks
    cat >> "$COMPOSE_FILE" << EOF
networks:
  agentx-network:
    driver: bridge
    name: agentx-network
EOF
}

# 生成配置文件
generate_compose_file

echo -e "${GREEN}✅ 配置文件生成完成: $COMPOSE_FILE${NC}"
echo

# 确认部署
echo -e "${YELLOW}🚀 准备开始部署，是否继续?${NC}"
read -p "继续部署? [Y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}部署已取消${NC}"
    exit 0
fi

# 检查必要的依赖
echo -e "${BLUE}🔍 检查系统依赖...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}错误: Docker Compose 未安装${NC}"
    exit 1
fi

# 创建日志目录
mkdir -p logs/backend logs/gateway logs/frontend

# 克隆API网关项目（如果需要）
if [ "$USE_API_GATEWAY" = true ]; then
    echo -e "${BLUE}📦 检查API网关项目...${NC}"
    API_GATEWAY_DIR="$PROJECT_ROOT/API-Premium-Gateway"
    if [ ! -d "$API_GATEWAY_DIR" ]; then
        echo -e "${YELLOW}正在克隆API网关项目...${NC}"
        git clone https://github.com/lucky-aeon/API-Premium-Gateway.git "$API_GATEWAY_DIR"
    fi
fi

# 开始部署
echo -e "${BLUE}🚀 开始部署服务...${NC}"

# 停止现有服务
echo -e "${YELLOW}停止现有服务...${NC}"
if docker compose version &> /dev/null; then
    docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
else
    docker-compose -f "$COMPOSE_FILE" down 2>/dev/null || true
fi

# 启动服务
echo -e "${YELLOW}启动新服务...${NC}"
if docker compose version &> /dev/null; then
    docker compose -f "$COMPOSE_FILE" up --build -d
else
    docker-compose -f "$COMPOSE_FILE" up --build -d
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 服务启动失败${NC}"
    exit 1
fi

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 10

# 显示服务状态
echo -e "${BLUE}📊 检查服务状态...${NC}"
if docker compose version &> /dev/null; then
    docker compose -f "$COMPOSE_FILE" ps
else
    docker-compose -f "$COMPOSE_FILE" ps
fi

echo
echo -e "${GREEN}"
echo "🎉 ========================================================= 🎉"
echo "                    🚀 AGENTX 部署完成! 🚀                   "
echo "🎉 ========================================================= 🎉"
echo -e "${NC}"

echo -e "${BLUE}📱 服务访问地址:${NC}"
echo "  - 前端应用: http://localhost:3000"
echo "  - 后端API: http://localhost:8080"
if [ "$USE_API_GATEWAY" = true ]; then
    echo "  - API网关: http://localhost:8081"
fi
echo "  - MCP网关: http://localhost:8005"
if [ "$USE_EXTERNAL_DB" = false ]; then
    echo "  - 数据库: localhost:5432"
fi

echo
echo -e "${YELLOW}🔐 默认登录账号:${NC}"
echo "  - 管理员: admin@agentx.ai / admin123"
echo "  - 测试用户: test@agentx.ai / test123"

echo
echo -e "${BLUE}📋 常用命令:${NC}"
echo "  - 查看状态: docker compose -f $COMPOSE_FILE ps"
echo "  - 查看日志: docker compose -f $COMPOSE_FILE logs -f [服务名]"
echo "  - 停止服务: docker compose -f $COMPOSE_FILE down"
echo "  - 重新部署: $0"

echo
echo -e "${GREEN}✅ 部署完成！${NC}"