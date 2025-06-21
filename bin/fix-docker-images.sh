#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Docker镜像问题紧急修复脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${YELLOW}🛠️  修复Docker镜像路径问题...${NC}"

# 修复 Dockerfile
echo -e "${BLUE}1. 修复 Dockerfile...${NC}"
cat > "$PROJECT_ROOT/AgentX/Dockerfile" << 'EOF'
# 使用官方OpenJDK镜像（通过配置的镜像源加速）
FROM openjdk:17-jdk-slim

WORKDIR /app

# 配置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 使用国内源并安装必要工具
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY target/agent-x-*.jar app.jar

# 创建日志目录
RUN mkdir -p /app/logs

# 暴露应用端口
EXPOSE 8080

# 设置JVM参数
ENV JAVA_OPTS="-Xms512m -Xmx1024m -Djava.security.egd=file:/dev/./urandom"

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
EOF

# 配置Docker镜像源
echo -e "${BLUE}2. 配置Docker镜像源...${NC}"
sudo mkdir -p /etc/docker

# 备份现有配置
if [ -f /etc/docker/daemon.json ]; then
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# 创建新的镜像源配置
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com",
    "https://dockerproxy.com"
  ],
  "dns": ["8.8.8.8", "114.114.114.114"],
  "insecure-registries": [],
  "debug": false,
  "experimental": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 重启Docker服务
echo -e "${BLUE}3. 重启Docker服务...${NC}"
sudo systemctl restart docker

# 等待Docker启动
echo -e "${YELLOW}等待Docker服务启动...${NC}"
for i in {1..30}; do
    if docker info &> /dev/null; then
        break
    fi
    echo -n "."
    sleep 1
done
echo

if docker info &> /dev/null; then
    echo -e "${GREEN}✅ Docker服务重启成功${NC}"
else
    echo -e "${RED}❌ Docker服务启动失败${NC}"
    exit 1
fi

# 清理旧镜像缓存
echo -e "${BLUE}4. 清理Docker缓存...${NC}"
docker system prune -f &> /dev/null || true

# 预拉取常用镜像
echo -e "${BLUE}5. 预拉取镜像...${NC}"
echo -e "${YELLOW}正在拉取 openjdk:17-jdk-slim...${NC}"
if docker pull openjdk:17-jdk-slim; then
    echo -e "${GREEN}✅ openjdk:17-jdk-slim 拉取成功${NC}"
else
    echo -e "${RED}❌ openjdk:17-jdk-slim 拉取失败${NC}"
fi

echo -e "${YELLOW}正在拉取 maven:3.9.6-eclipse-temurin-17...${NC}"
if docker pull maven:3.9.6-eclipse-temurin-17; then
    echo -e "${GREEN}✅ maven:3.9.6-eclipse-temurin-17 拉取成功${NC}"
else
    echo -e "${RED}❌ maven:3.9.6-eclipse-temurin-17 拉取失败${NC}"
fi

echo -e "${YELLOW}正在拉取 postgres:15-alpine...${NC}"
if docker pull postgres:15-alpine; then
    echo -e "${GREEN}✅ postgres:15-alpine 拉取成功${NC}"
else
    echo -e "${RED}❌ postgres:15-alpine 拉取失败${NC}"
fi

echo
echo -e "${GREEN}"
echo "🎉 ============================================== 🎉"
echo "         🔧 Docker镜像问题修复完成! 🔧          "
echo "🎉 ============================================== 🎉"
echo -e "${NC}"

echo -e "${BLUE}📋 修复内容:${NC}"
echo "  ✅ 修复了Docker镜像路径问题"
echo "  ✅ 配置了国内镜像源"
echo "  ✅ 重启了Docker服务"
echo "  ✅ 预拉取了常用镜像"

echo
echo -e "${GREEN}🚀 现在可以重新部署了:${NC}"
echo "  cd /opt/agentx"
echo "  ./bin/deploy.sh"

echo
echo -e "${BLUE}💡 如果还有问题，可以尝试:${NC}"
echo "  - 手动拉取镜像: docker pull openjdk:17-jdk-slim"
echo "  - 检查网络连接: ping docker.mirrors.ustc.edu.cn"
echo "  - 查看Docker状态: docker info"