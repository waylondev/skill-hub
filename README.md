# Skill-Hub

> **把 Confluence 的理论知识，变成 AI 帮你干活的能力**
>
> Confluence 告诉你怎么做，Skill-Hub 让 AI 帮你做。

---

## 问题：知识在 Confluence 里"睡觉"

集团内部存在大量**只有内部才知道的重复性流程**：

- 新员工入职要申请 VPN、Jenkins、ServiceNow、IKP、Vault、G3 等十几个系统的权限
- 安装软件要先在 ServiceNow 提申请，审批后推送到 Software Center，再安装，再配置环境变量
- 配置 Maven/Node 等包管理工具要连接内部 Nexus 镜像

**现状**：这些知识散落在 Confluence、飞书文档、老员工脑子里。

**本质问题**：Confluence 是**理论知识库**——你读完文档，知道了流程，然后**自己去操作**。每次都要：查文档 → 理解流程 → 打开对应系统 → 按步骤操作。知识停留在"被阅读"的阶段，从未转化为"被执行"的能力。

---

## 解决方案：让 AI 帮你干活

Skill-Hub 把 Confluence 里的**理论知识**转化为 AI Agent 可以直接执行的**操作能力**。

### 对比：Confluence vs Skill-Hub

| | Confluence（现在） | Skill-Hub（未来） |
|---|---|---|
| **知识形态** | 文档，需要人去读 | 结构化指令，AI 直接执行 |
| **操作方式** | 人读文档 → 人去操作 | 人说一句话 → AI 帮你干 |
| **出错率** | 步骤多、系统多，容易遗漏 | AI 按指令逐步执行，不会遗漏 |
| **新人体验** | 找不到、找不全、找不准 | 说一句话，全程自动 |
| **老员工负担** | 反复回答同样的问题 | 知识沉淀为 Skill，一次编写永久复用 |

---

## 示例：一句话让 AI 帮你装 Java

```
员工："帮我装 Java"
  → AI 理解意图，匹配到 3 个原子 Skill
  → AI 编排执行顺序：sn-request-software → swc-install-package → env-configure-java
  → 每步操作一个系统，AI 处理前置条件检查和异常
  → 从"查 Confluence 自己干"变成"AI 帮你干"
```

---

## 核心组成

- **Git 仓库**：存放所有 Skill
- **Go CLI 工具**：5 个命令管理 Skill（search/install/uninstall/run/push）
- **静态展示站**：向全员宣传已有 Skill

---

## 快速开始

### 1. 安装 CLI

```bash
# macOS / Linux
curl -fsSL https://github.com/company/skill-hub-cli/releases/latest/download/skill_$(uname -s)_$(uname -m) -o /usr/local/bin/skill && chmod +x /usr/local/bin/skill
```

### 2. 搜索 Skill

```bash
skill search java
```

### 3. 安装并使用

```bash
skill install sn-request-software
skill run sn-request-software
```

---

## 与腾讯 SkillHub 的区别

| | 腾讯 SkillHub | 我们的 Skill-Hub |
|---|---|---|
| **本质** | 技能分发平台（应用商店） | 内部流程知识库（操作说明书） |
| **Skill 来源** | 第三方开发者贡献，1.3 万+ | 内部员工编写，聚焦本集团 |
| **Skill 内容** | 代码/插件（可执行程序） | 自然语言描述（SKILL.md） |
| **核心价值** | 高速下载、精选榜单、安全审计 | 从"看文档"到"AI帮你干" |
| **解决的问题** | 海量技能的发现与安装 | 内部重复性流程的自动化 |

**一句话总结**：腾讯 SkillHub 是"应用商店"，帮你找到并安装工具；我们的 Skill-Hub 是"操作手册"，让 AI 帮你执行内部流程。两者互补，不冲突。

---

## 首批 Skill 清单

| 分类 | Skill | 说明 |
|------|-------|------|
| ServiceNow | `sn-request-software` | 申请软件 |
| ServiceNow | `sn-request-permission` | 申请系统权限 |
| Software Center | `swc-install-package` | 安装已审批软件 |
| 环境配置 | `env-configure-java` | 配置 Java 环境变量 |
| 环境配置 | `env-configure-maven` | 配置 Maven 环境变量 |
| Nexus | `nexus-configure-maven` | 配置 Maven Nexus 镜像 |
| VPN | `vpn-apply-permission` | 申请 VPN 权限 |

---

## 贡献 Skill

1. 编写 `SKILL.md`（参考示例）
2. `skill push ./skills/your-skill`
3. 提交 PR 合并

---

## 文档

- [PRD v3.2](./Skill-Hub-PRD-v3.0.md) - 产品需求文档
- [实施指南](./Skill-Hub-实施指南.md) - 开发任务清单
