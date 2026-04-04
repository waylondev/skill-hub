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

一个 Skill 只做**