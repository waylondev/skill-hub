# Agent Skills 最佳实践

> 基于 [Agent Skills 官方文档](https://agentskills.io) 的行业标准
>
> **参考文档**：
> - https://agentskills.io/home
> - https://agentskills.io/what-are-skills
> - https://agentskills.io/skill-creation/best-practices
> - https://agentskills.io/skill-creation/optimizing-descriptions

---

## 1. Skill 描述优化原则

### 1.1 使用命令式表述

**✅ 推荐**：
```yaml
description: >-
  Use this skill when the user wants to configure Git, set up Git username, or configure Git email.
```

**❌ 避免**：
```yaml
description: >-
  该 Skill 在用户要求"配置 Git"、"设置 Git 用户名"时使用。
```

### 1.2 聚焦用户意图，而非实现细节

描述应该关注**用户想要达成什么**，而不是 Skill 内部如何工作。

**✅ 推荐**：
- "Use this skill when the user wants to configure npm mirror"
- "Use this skill when the user wants to request software installation"

**❌ 避免**：
- "该 Skill 会调用 ServiceNow API 提交申请"
- "这个 Skill 会修改 .npmrc 文件"

### 1.3 明确列出适用场景

主动列出 Skill 适用的上下文，即使用户没有明确提到相关关键词。

**示例**：
```yaml
description: >-
  Use this skill when the user wants to configure npm mirror, set up .npmrc,
  or configure internal Nexus npm registry, even if they don't explicitly mention "npm" or "registry".
```

### 1.4 保持简洁

- 长度：几句话到一个短段落
- 足够覆盖 Skill 范围
- 足够简短，不会在多个 Skill 上下文中膨胀
- 官方建议：≤ 1024 字符

---

## 2. Skill 设计核心原则

### 2.1 原子能力 (Atomic)

一个 Skill 只做**一件事**，只操作**一个系统**。

**✅ 好的 Skill**：
- `sn-request-software` - 只在 ServiceNow 申请软件
- `env-configure-java` - 只配置 Java 环境变量
- `swc-install-package` - 只在 Software Center 安装

**❌ 坏的 Skill**：
- `install-and-configure-java` - 既申请又安装又配置（跨 3 个系统）

### 2.2 不做编排 (No Orchestration)

**编排是 AI Agent 的职责**，Skill 绝对不做编排。

**为什么？**
- AI 能理解上下文、判断前置条件、处理异常
- 预定义的编排逻辑无法适应不同场景
- 原子 Skill 可以被 AI 自由组合，复用度更高

**示例**：用户说"我要装 Java"
- ❌ Skill 内部写死：申请 → 安装 → 配置
- ✅ AI 自主编排：`sn-request-software` → `swc-install-package` → `env-configure-java`

### 2.3 单一职责 (Single Responsibility)

遵循 SOLID 的单一职责原则，一个 Skill 只负责一个系统的一个操作。

### 2.4 幂等性 (Idempotent)

相同输入多次执行，结果一致。

**在约束中明确说明**：
```markdown
## 约束
- 幂等：已配置则检查是否正确，不重复配置
```

### 2.5 不包装工具 (No Tool Wrapping)

Skill 聚焦**内部流程知识**，不教 Agent 怎么用 CLI。

**✅ Skill 应该包含**：
- 内部门户地址
- 审批链
- 指定版本
- 公司特有配置

**❌ Skill 不应该包含**：
- "教你怎么用 git config"
- "教你怎么用 npm install"

---

## 3. SKILL.md 结构

### 3.1 Frontmatter

```yaml
---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git, set up Git username,
  or configure Git email.
version: 1.0.0
displayName: 配置 Git
domain: env
action: configure
object: git
tags: [env, git, scm, config]
type: SKILL
inputs:
  - name: user_name
    type: string
    required: true
    description: Git 用户名
  - name: user_email
    type: string
    required: true
    description: Git 邮箱
---
```

### 3.2 Body 推荐结构

| 章节 | 用途 | 必需 |
|------|------|------|
| `## 触发条件` | 何时使用 | ✅ |
| `## 前置条件` | 依赖的系统状态 | ✅ |
| `## 执行步骤` | 具体操作（含内部地址等） | ✅ |
| `## 约束` | 边界 + 幂等性保障 | ✅ |

**不推荐包含**：
- 相关 Skill 列表（AI 会自主发现）
- 过多可选配置示例
- 冗长的背景说明

---

## 4. 命名规范

格式：`{domain}-{action}-{object}`

**域编码**：
- `sn` - ServiceNow
- `swc` - Software Center
- `env` - 环境变量
- `nexus` - Nexus 制品仓库
- `vpn` - VPN
- `hr` - 人力资源系统
- `doc` - 文档系统

**示例**：
- `sn-request-software` - ServiceNow 申请软件
- `swc-install-package` - Software Center 安装包
- `env-configure-java` - 环境配置 Java

---

## 5. Skill 触发评估

### 5.1 Should-Trigger 查询

测试 Skill 应该触发的场景：
- 正式和非正式的表述
- 有拼写错误或缩写
- 直接提到 Skill 领域或间接描述需求
- 简洁提示和详细上下文混合
- 单步和多步工作流

**示例**：
- "Configure Git for me"
- "Set up my Git username and email"
- "I need to configure Git before I commit"

### 5.2 Should-Not-Trigger 查询

测试 Skill 不应该触发的场景：
- 明显不相关的（用于测试边界）
- 共享概念但需要不同操作的
- 涉及关键词但任务不同的

**示例**：
- "Install Git"（安装 vs 配置）
- "Commit my code"（使用 Git vs 配置 Git）

---

## 6. 优化循环

1. 在训练集和验证集上评估当前描述
2. 识别训练集中的失败案例
3. 修订描述：
   - 如果应该触发的查询失败：拓宽范围
   - 如果不应该触发的查询误触发：增加特异性
4. 检查描述保持在 1024 字符限制内
5. 重复直到训练集全部通过或无明显改进
6. 选择验证集通过率最高的版本

---

## 7. 快速检查表

创建新 Skill 前，请确认：

- [ ] 描述使用命令式 "Use this skill when..."
- [ ] 描述聚焦用户意图，而非实现细节
- [ ] 描述简洁（≤ 1024 字符）
- [ ] Skill 只做一件事（原子能力）
- [ ] Skill 不做编排
- [ ] Skill 只操作一个系统
- [ ] 约束中明确说明幂等性
- [ ] 命名符合 `{domain}-{action}-{object}` 格式
- [ ] 包含内部特有知识（地址、审批链等）
- [ ] 不包装通用 CLI 工具
