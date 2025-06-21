#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🗄️  PostgreSQL 自动安装脚本${NC}"
echo -e "${BLUE}================================${NC}"
echo

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VERSION=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="CentOS"
        VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
    else
        echo -e "${RED}❌ 无法检测操作系统${NC}"
        exit 1
    fi
}

# 安装PostgreSQL
install_postgresql() {
    echo -e "${YELLOW}🔍 检测到操作系统: $OS $VERSION${NC}"
    echo
    
    case "$OS" in
        "Ubuntu"* | "Debian"*)
            echo -e "${YELLOW}📦 在 Ubuntu/Debian 上安装 PostgreSQL...${NC}"
            
            # 更新包列表
            sudo apt update
            
            # 安装PostgreSQL
            sudo apt install -y postgresql postgresql-contrib postgresql-client
            
            # 启动并启用PostgreSQL
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            echo -e "${GREEN}✅ PostgreSQL 安装完成${NC}"
            ;;
            
        "CentOS"* | "Red Hat"* | "Rocky"* | "AlmaLinux"*)
            echo -e "${YELLOW}📦 在 CentOS/RHEL 上安装 PostgreSQL...${NC}"
            
            # 安装EPEL仓库
            sudo yum install -y epel-release
            
            # 安装PostgreSQL
            sudo yum install -y postgresql-server postgresql postgresql-contrib
            
            # 初始化数据库
            sudo postgresql-setup initdb
            
            # 启动并启用PostgreSQL
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            echo -e "${GREEN}✅ PostgreSQL 安装完成${NC}"
            ;;
            
        "Amazon Linux"*)
            echo -e "${YELLOW}📦 在 Amazon Linux 上安装 PostgreSQL...${NC}"
            
            # 安装PostgreSQL
            sudo yum install -y postgresql-server postgresql postgresql-contrib
            
            # 初始化数据库
            sudo postgresql-setup initdb
            
            # 启动并启用PostgreSQL
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            echo -e "${GREEN}✅ PostgreSQL 安装完成${NC}"
            ;;
            
        *)
            echo -e "${RED}❌ 不支持的操作系统: $OS${NC}"
            echo -e "${YELLOW}请手动安装 PostgreSQL${NC}"
            return 1
            ;;
    esac
}

# 配置PostgreSQL
configure_postgresql() {
    echo -e "${YELLOW}🔧 配置 PostgreSQL...${NC}"
    
    # 查找PostgreSQL版本和配置文件路径
    PG_VERSION=$(sudo -u postgres psql -t -c "SELECT version();" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    
    # 常见的配置文件路径
    PG_CONFIG_PATHS=(
        "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
        "/var/lib/pgsql/data/postgresql.conf"
        "/var/lib/postgresql/data/postgresql.conf"
        "/usr/local/pgsql/data/postgresql.conf"
    )
    
    PG_HBA_PATHS=(
        "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
        "/var/lib/pgsql/data/pg_hba.conf"
        "/var/lib/postgresql/data/pg_hba.conf"
        "/usr/local/pgsql/data/pg_hba.conf"
    )
    
    # 查找配置文件
    PG_CONFIG=""
    PG_HBA=""
    
    for path in "${PG_CONFIG_PATHS[@]}"; do
        if [ -f "$path" ]; then
            PG_CONFIG="$path"
            break
        fi
    done
    
    for path in "${PG_HBA_PATHS[@]}"; do
        if [ -f "$path" ]; then
            PG_HBA="$path"
            break
        fi
    done
    
    if [ -z "$PG_CONFIG" ] || [ -z "$PG_HBA" ]; then
        echo -e "${YELLOW}⚠️  无法找到 PostgreSQL 配置文件，使用默认配置${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📝 配置文件路径:${NC}"
    echo "  - postgresql.conf: $PG_CONFIG"
    echo "  - pg_hba.conf: $PG_HBA"
    
    # 备份原配置文件
    sudo cp "$PG_CONFIG" "$PG_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp "$PG_HBA" "$PG_HBA.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 配置PostgreSQL监听地址
    echo -e "${YELLOW}配置网络访问...${NC}"
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG"
    
    # 配置认证方式
    echo -e "${YELLOW}配置访问权限...${NC}"
    
    # 检查是否已存在配置
    if ! sudo grep -q "host.*all.*all.*0.0.0.0/0.*md5" "$PG_HBA"; then
        # 在local connections之后添加网络访问规则
        sudo sed -i '/^local.*all.*all.*peer/a host    all             all             0.0.0.0/0               md5' "$PG_HBA"
    fi
    
    # 重启PostgreSQL使配置生效
    echo -e "${YELLOW}重启 PostgreSQL 服务...${NC}"
    sudo systemctl restart postgresql
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PostgreSQL 配置完成${NC}"
    else
        echo -e "${RED}❌ PostgreSQL 重启失败${NC}"
        return 1
    fi
}

# 设置postgres用户密码
setup_postgres_password() {
    echo -e "${YELLOW}🔐 设置 postgres 用户密码...${NC}"
    
    # 生成随机密码或让用户输入
    read -p "为 postgres 用户设置密码 (留空自动生成): " POSTGRES_PASSWORD
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        # 生成随机密码
        POSTGRES_PASSWORD=$(openssl rand -base64 12 2>/dev/null || echo "postgres123")
        echo -e "${BLUE}🎲 自动生成密码: $POSTGRES_PASSWORD${NC}"
    fi
    
    # 设置密码
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ postgres 用户密码设置成功${NC}"
        
        # 保存密码到文件
        echo "POSTGRES_ADMIN_PASSWORD=$POSTGRES_PASSWORD" > ~/.postgres_admin
        chmod 600 ~/.postgres_admin
        echo -e "${BLUE}💾 密码已保存到: ~/.postgres_admin${NC}"
    else
        echo -e "${RED}❌ 密码设置失败${NC}"
        return 1
    fi
}

# 安装pgvector扩展 (可选)
install_pgvector() {
    echo -e "${YELLOW}🧩 安装 pgvector 扩展 (用于向量数据库功能)...${NC}"
    
    read -p "是否安装 pgvector 扩展? [Y/n]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        case "$OS" in
            "Ubuntu"* | "Debian"*)
                sudo apt install -y postgresql-$PG_VERSION-pgvector 2>/dev/null || {
                    echo -e "${YELLOW}⚠️  从apt安装失败，尝试从源码编译...${NC}"
                    compile_pgvector
                }
                ;;
            *)
                compile_pgvector
                ;;
        esac
    else
        echo -e "${YELLOW}⏭️  跳过 pgvector 安装${NC}"
    fi
}

# 从源码编译pgvector
compile_pgvector() {
    echo -e "${YELLOW}🔨 从源码编译 pgvector...${NC}"
    
    # 安装编译依赖
    case "$OS" in
        "Ubuntu"* | "Debian"*)
            sudo apt install -y build-essential postgresql-server-dev-all git
            ;;
        "CentOS"* | "Red Hat"* | "Rocky"* | "AlmaLinux"*)
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y postgresql-devel git
            ;;
    esac
    
    # 克隆并编译pgvector
    cd /tmp
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git
    cd pgvector
    make
    sudo make install
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ pgvector 编译安装成功${NC}"
    else
        echo -e "${YELLOW}⚠️  pgvector 安装失败，但不影响主要功能${NC}"
    fi
    
    # 清理
    cd /
    rm -rf /tmp/pgvector
}

# 测试PostgreSQL安装
test_postgresql() {
    echo -e "${YELLOW}🧪 测试 PostgreSQL 安装...${NC}"
    
    # 测试连接
    if sudo -u postgres psql -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL 运行正常${NC}"
        
        # 显示版本信息
        PG_VERSION_FULL=$(sudo -u postgres psql -t -c "SELECT version();" | xargs)
        echo -e "${BLUE}📊 版本信息: $PG_VERSION_FULL${NC}"
        
        # 测试pgvector
        if sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ pgvector 扩展可用${NC}"
        else
            echo -e "${YELLOW}⚠️  pgvector 扩展不可用${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ PostgreSQL 连接失败${NC}"
        return 1
    fi
}

# 显示安装结果
show_results() {
    echo
    echo -e "${GREEN}"
    echo "🎉 ================================================ 🎉"
    echo "           🗄️  PostgreSQL 安装完成! 🗄️            "
    echo "🎉 ================================================ 🎉"
    echo -e "${NC}"
    
    echo -e "${BLUE}📋 安装信息:${NC}"
    echo "  - PostgreSQL 版本: $(sudo -u postgres psql -t -c "SELECT version();" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
    echo "  - 服务状态: $(systemctl is-active postgresql)"
    echo "  - 端口: 5432"
    echo "  - 数据目录: $(sudo -u postgres psql -t -c "SHOW data_directory;" | xargs)"
    
    echo
    echo -e "${BLUE}🔐 管理员账号:${NC}"
    echo "  - 用户名: postgres"
    echo "  - 密码: [保存在 ~/.postgres_admin]"
    
    echo
    echo -e "${BLUE}📱 下一步操作:${NC}"
    echo "  1. 运行部署脚本: ./bin/deploy.sh"
    echo "  2. 选择生产模式(3) 使用独立数据库"
    echo "  3. 或运行: ./bin/setup-external-db.sh 初始化应用数据库"
    
    echo
    echo -e "${BLUE}🛠️  常用命令:${NC}"
    echo "  - 连接数据库: sudo -u postgres psql"
    echo "  - 查看状态: systemctl status postgresql"
    echo "  - 重启服务: sudo systemctl restart postgresql"
    echo "  - 查看日志: sudo journalctl -u postgresql -f"
    
    if [ -f ~/.postgres_admin ]; then
        echo
        echo -e "${YELLOW}💡 管理员密码已保存到 ~/.postgres_admin 文件中${NC}"
        echo -e "${YELLOW}   可以通过 'source ~/.postgres_admin && echo \$POSTGRES_ADMIN_PASSWORD' 查看${NC}"
    fi
    
    echo
    echo -e "${GREEN}✅ PostgreSQL 安装配置完成！${NC}"
}

# 主执行流程
main() {
    echo -e "${BLUE}开始安装 PostgreSQL...${NC}"
    echo
    
    # 检查是否已安装
    if command -v psql &> /dev/null && systemctl is-active postgresql &> /dev/null; then
        echo -e "${YELLOW}⚠️  PostgreSQL 似乎已经安装并运行${NC}"
        read -p "是否继续重新配置? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}使用现有 PostgreSQL 安装${NC}"
            test_postgresql
            exit 0
        fi
    fi
    
    # 检查权限
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}❌ 请不要以 root 用户运行此脚本${NC}"
        echo -e "${YELLOW}💡 使用普通用户运行，脚本会在需要时请求 sudo 权限${NC}"
        exit 1
    fi
    
    # 检查sudo权限
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}🔑 需要 sudo 权限来安装 PostgreSQL${NC}"
        sudo -v
    fi
    
    # 执行安装步骤
    detect_os
    
    if install_postgresql; then
        configure_postgresql
        setup_postgres_password
        install_pgvector
        
        if test_postgresql; then
            show_results
        else
            echo -e "${RED}❌ PostgreSQL 安装完成但测试失败${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ PostgreSQL 安装失败${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"