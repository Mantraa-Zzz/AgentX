# AgentX - 智能对话系统平台

[](https://opensource.org/licenses/MIT)

AgentX 是一个基于大模型 (LLM) 和多能力平台 (MCP) 的智能 Agent 构建平台。它致力于简化 Agent 的创建流程，让用户无需复杂的流程节点或拖拽操作，仅通过自然语言和工具集成即可打造个性化的智能 Agent。

## 🔗 相关链接

### 📦 子仓库
- 🛡️ **高可用网关**: [API-Premium-Gateway](https://github.com/lucky-aeon/API-Premium-Gateway) - 模型高可用组件
- 🌐 **MCP网关**: [mcp-gateway](https://github.com/lucky-aeon/mcp-gateway) - MCP服务统一管理
- 🏪 **MCP社区**: [agent-mcp-community](https://github.com/lucky-aeon/agent-mcp-community) - MCP Server 开源社区

### 📚 学习资源
- 🎥 **项目教程**: [B站视频教程](https://www.bilibili.com/video/BV1qaTWzPERJ/?spm_id_from=333.1387.homepage.video_card.click)
- 📖 **详细教学**: [敲鸭社区 - code.xhyovo.cn](https://code.xhyovo.cn/)
- 🎯 **项目演示**: [在线PPT介绍](https://needless-comparison.surge.sh)

## ⏳ 功能
 - [x] Agent 管理（创建/发布）
 - [x] LLM 上下文管理（滑动窗口，摘要算法）
 - [x] Agent 策略（MCP）
 - [x] 大模型服务商
 - [x] 用户
 - [x] 工具市场
 - [x] MCP Server Community
 - [x] MCP Gateway 
 - [x] 预先设置工具
 - [x] Agent 定时任务
 - [x] Agent OpenAPI
 - [x] 模型高可用组件
 - [x] RAG
 - [x] 计费
 - [ ] Multi Agent
 - [ ] Agent 监控
 - [ ] 知识图谱
 - [ ] 长期记忆 
 
## 🚀 快速部署

### 👥 用户部署（生产环境）

适用于想要快速体验或部署生产环境的用户，**无需下载源码**：

```bash
# 一键启动（最简单）
docker run -d \
  --name agentx \
  -p 3000:3000 \
  -p 8080:8080 \
  ghcr.io/lucky-aeon/agentx:latest
```

**访问地址**：
- 前端：http://localhost:3000  
- 后端：http://localhost:8080

**默认账号**：
- 管理员：admin@agentx.ai / admin123
- 测试用户：test@agentx.ai / test123

### 👨‍💻 开发者部署（开发环境）

适用于需要修改代码的开发者：

```bash
# 1. 克隆项目
git clone https://github.com/lucky-aeon/AgentX.git
cd AgentX/deploy

# 2. 启动开发环境
./start.sh
```

**开发环境特色**：
- 🔥 代码热重载
- 🛠 数据库管理工具 (http://localhost:8081)
- 🐛 调试端口开放
- 📊 详细开发日志

### 📖 详细文档

| 文档 | 说明 |
|------|------|
| [生产部署指南](docs/deployment/PRODUCTION_DEPLOY.md) | 用户生产环境部署 |
| [开发部署指南](deploy/README.md) | 开发者环境配置 |
| [故障排查手册](docs/deployment/TROUBLESHOOTING.md) | 问题诊断和解决 |

## 功能介绍

## Contributors

[![AgentX](https://contrib.rocks/image?repo=lucky-aeon/agentX)](https://contrib.rocks/image?repo=lucky-aeon/agentX)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=lucky-aeon/agentX&type=Date)](https://api.star-history.com/svg?repos=lucky-aeon/agentX&type=Date)


## 联系我们

我们致力于构建一个活跃的开发者社区，欢迎各种形式的交流与合作！

### 📱 私人微信
如有技术问题或商务合作，可添加开发者微信：

<img src="docs/images/wechat.jpg" alt="私人微信" width="200"/>

### 👥 微信交流群
加入我们的技术交流群，与更多开发者一起讨论：

<img src="docs/images/group.jpg" alt="微信交流群" width="200"/>

### 📢 微信公众号
关注我们的公众号，获取最新技术动态和产品更新：

<img src="docs/images/微信公众号.jpg" alt="微信公众号" width="200"/>

---

**如果二维码过期或无法扫描，请通过私人微信联系我。**