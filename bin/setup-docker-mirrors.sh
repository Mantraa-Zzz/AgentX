#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🐳 Docker 国内镜像源配置脚本${NC}"
echo -e "${BLUE}================================${NC}"
echo

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查是否为root用户或有sudo权限
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}🔑 需要管理员权限配置 Docker${NC}"
    sudo -v
fi

# 备份现有配置
DOCKER_CONFIG_DIR="/etc/docker"
DOCKER_CONFIG_FILE="$DOCKER_CONFIG_DIR/daemon.json"

echo -e "${YELLOW}📋 配置 Docker 国内镜像源...${NC}"

# 创建Docker配置目录
if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
    echo -e "${BLUE}创建 Docker 配置目录...${NC}"
    sudo mkdir -p "$DOCKER_CONFIG_DIR"
fi

# 备份现有配置
if [ -f "$DOCKER_CONFIG_FILE" ]; then
    echo -e "${YELLOW}备份现有配置...${NC}"
    sudo cp "$DOCKER_CONFIG_FILE" "$DOCKER_CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
fi

# 复制配置文件
echo -e "${BLUE}配置国内镜像源...${NC}"
sudo cp "$PROJECT_ROOT/daemon.json" "$DOCKER_CONFIG_FILE"

# 重启Docker服务
echo -e "${YELLOW}重启 Docker 服务...${NC}"
if systemctl is-active --quiet docker; then
    sudo systemctl restart docker
    
    # 等待Docker启动
    echo -e "${YELLOW}等待 Docker 服务启动...${NC}"
    for i in {1..30}; do
        if docker info &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 1
    done
    echo
    
    if docker info &> /dev/null; then
        echo -e "${GREEN}✅ Docker 服务重启成功${NC}"
    else
        echo -e "${RED}❌ Docker 服务启动失败${NC}"
        exit 1
    fi
else
    sudo systemctl start docker
    sudo systemctl enable docker
    echo -e "${GREEN}✅ Docker 服务已启动${NC}"
fi

# 验证配置
echo -e "${BLUE}🧪 验证镜像源配置...${NC}"
if docker info | grep -A 10 "Registry Mirrors" | grep -q "registry.cn-hangzhou.aliyuncs.com"; then
    echo -e "${GREEN}✅ 国内镜像源配置成功${NC}"
    
    echo -e "${BLUE}📊 当前配置的镜像源:${NC}"
    docker info | grep -A 5 "Registry Mirrors" | grep -E "^\s+https://" | sed 's/^/  - /'
else
    echo -e "${YELLOW}⚠️  镜像源配置可能未生效，请手动检查${NC}"
fi

# 测试镜像拉取
echo -e "${BLUE}🧪 测试镜像拉取速度...${NC}"
echo -e "${YELLOW}正在拉取测试镜像 hello-world...${NC}"

start_time=$(date +%s)
if docker pull hello-world &> /dev/null; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo -e "${GREEN}✅ 镜像拉取成功，耗时: ${duration}秒${NC}"
    
    # 清理测试镜像
    docker rmi hello-world &> /dev/null
else
    echo -e "${RED}❌ 镜像拉取失败${NC}"
fi

echo
echo -e "${GREEN}"
echo "🎉 ============================================== 🎉"
echo "         🐳 Docker 镜像源配置完成! 🐳           "
echo "🎉 ============================================== 🎉"
echo -e "${NC}"

echo -e "${BLUE}📋 配置信息:${NC}"
echo "  - 配置文件: $DOCKER_CONFIG_FILE"
echo "  - 主镜像源: registry.cn-hangzhou.aliyuncs.com"
echo "  - 备用镜像源: docker.mirrors.ustc.edu.cn"
echo

echo -e "${BLUE}💡 使用建议:${NC}"
echo "  - 镜像源已优化为国内高速节点"
echo "  - 支持 Docker Hub 的所有镜像"
echo "  - 如遇问题可恢复备份配置"

echo -e "${BLUE}🔧 常用命令:${NC}"
echo "  - 查看配置: docker info | grep -A 5 'Registry Mirrors'"
echo "  - 重启服务: sudo systemctl restart docker"
echo "  - 恢复配置: sudo cp $DOCKER_CONFIG_FILE.backup.* $DOCKER_CONFIG_FILE"

echo
echo -e "${GREEN}✅ 现在可以高速拉取 Docker 镜像了！${NC}"