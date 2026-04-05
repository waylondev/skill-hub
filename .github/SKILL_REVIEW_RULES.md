# SKILL File Review 规则

## 使用说明

这是专门用于 review Skill-Hub 项目中 SKILL.md 文件的规则。确保所有 Skill 文件符合官方规范。

---

## 📋 Review 检查清单

### 1. Frontmatter 检查 ✅

**必须包含的字段**：
- [ ] `name`: 技能名称（必填）
- [ ] `description`: 技能描述（必填）
- [ ] `version`: 版本号（必填）
- [ ] `displayName`: 显示名称（建议）
- [ ] `domain`: 领域代码（必填）
- [ ] `action`: 动作（必填）
- [ ] `object`: 对象（必填）
- [ ] `type`: 类型（必填，值为 SKILL）

**命名规范检查**：
- [ ] `name` 是否遵循 `{domain}-{action}-{object}` 格式
- [ ] `domain` 是否是有效的领域代码（sn, swc, env, nexus, vpn, hr, doc）
- [ ] 名称是否全部小写，使用连字符分隔

**Description 质量检查**：
- [ ] 是否使用祈使句 "Use this skill when..."
- [ ] 是否聚焦用户意图，而非实现细节
- [ ] 是否明确列出适用场景
- [ ] 是否简洁（≤ 1024 字符）
- [ ] 是否包含触发场景示例

**示例**：
```yaml
# ✅ Good
description: >-
  Use this skill when the user wants to configure Git, set up Git username,
  or configure Git email.

# ❌ Bad
description: >-
  This skill is used to configure git...  # 不是祈使句
```

---

### 2. SKILL.md 结构检查 📐

**必须包含的章节**：
- [ ] `## Trigger Conditions` - 何时使用此技能
- [ ] `## Prerequisites` - 前置条件
- [ ] `## Execution Steps` - 执行步骤
- [ ] `## Constraints` - 约束和边界

**推荐内容**：
- [ ] `## Purpose` - 简要说明（1-2 句话）
- [ ] `## Error Handling` - 错误处理

**不应包含**：
- [ ] Related Skills 列表（AI 会自主发现）
- [ ] 过多的可选配置示例
- [ ] 冗长的背景解释

---

### 3. 单一职责原则检查 🎯

**检查项**：
- [ ] 是否只做一件事（One Skill = One Action）
- [ ] 是否只操作一个系统
- [ ] 是否没有硬编码具体命令
- [ ] 是否没有编排逻辑（orchestration）

**示例**：
```markdown
# ✅ Good: 只配置环境变量
env-configure-maven - 只配置 MAVEN_HOME 和 PATH

# ❌ Bad: 做了太多事
install-and-configure-java - 请求、安装、配置（跨越 3 个系统）
```

---

### 4. 幂等性检查 🔄

**必须包含的检查逻辑**：
- [ ] 是否在修改前检查当前状态
- [ ] 如果已正确配置，是否告知用户并停止
- [ ] 是否只在需要时才执行配置

**错误消息规范**：
- [ ] "XXX is not installed. Please install XXX first."
- [ ] "XXX is not configured. Please use XXX skill first."
- [ ] "XXX is already set to {{value}}. No action needed."

**示例流程**：
```markdown
Step 1: Verify prerequisites → Not met? Inform user and stop
Step 2: Check current state → Already correct? Inform user and stop
Step 3: Apply configuration → Only if needed
Step 4: Verify result
Step 5: Inform user
```

---

### 5. 前置条件检查检查 ⚠️

**检查项**：
- [ ] 是否明确列出所有前置条件
- [ ] 如果前置条件不满足，是否告知用户
- [ ] 是否建议用户先使用哪个 Skill
- [ ] 是否停止执行（不做部分配置）

**示例**：
```markdown
### Step 1: Verify Prerequisites

- **Check if JAVA_HOME is set**: If not configured, inform user: 
  "JAVA_HOME is not configured. Please use env-configure-java skill first." 
  → **Stop and do not proceed.**
```

---

### 6. 无硬编码原则检查 🚫

**检查项**：
- [ ] 是否描述意图而非具体命令
- [ ] 是否没有硬编码具体命令（如 `git config --global user.name`）
- [ ] 是否让 AI 可以适应不同平台
- [ ] 是否使用意图描述而非指令

**示例**：
```markdown
# ❌ Bad (Hardcoded)
Run: git config --global user.name "John Doe"

# ✅ Good (Intent-based)
Set the global username that will appear in commits:
- Use the `user.name` configuration key
- Apply at global level
- If already configured correctly, skip this step (idempotent)
```

---

### 7. 约束和边界检查 📏

**必须明确说明**：
- [ ] 此 Skill **不**负责什么
- [ ] 操作级别（用户级 vs 系统级）
- [ ] 是否幂等
- [ ] 是否检查前置条件

**示例**：
```markdown
## Constraints

- **Single Responsibility**: Only configures environment variables. Does not configure settings.xml or repositories.
- **Idempotent**: Check first, configure only if needed.
- **Prerequisite Check**: If prerequisites are not met, inform user and stop.
- **User-level only**: Only modifies user environment variables (no system-wide changes).
```

---

### 8. 用户沟通检查 💬

**检查项**：
- [ ] 是否有成功确认消息
- [ ] 是否有下一步建议
- [ ] 是否有验证指导
- [ ] 错误消息是否具体、可操作

**示例消息**：
```markdown
- ✅ "Maven environment variables have been configured successfully"
- ℹ️ "You may need to restart your terminal for changes to take effect"
- 🔍 "Run `mvn --version` to verify the installation"
- ❌ "Maven is not installed. Please install Maven first."
```

---

### 9. 语言检查 🌐

**检查项**：
- [ ] 是否全部使用英文（Pure English）
- [ ] 是否没有中文内容
- [ ] 语法是否正确
- [ ] 用词是否清晰、专业

---

### 10. AI 赋能检查 🤖

**检查项**：
- [ ] 是否将编排留给 AI
- [ ] 是否让 AI 处理上下文推理
- [ ] 是否让 AI 处理异常
- [ ] 是否提供原子能力而非完整流程

---

## 📊 Review 输出格式

### ✅ 优点
列出 SKILL 文件中做得好的地方

### ⚠️ 需要改进

#### 高优先级（必须修复）
1. **缺少必需章节**：例如缺少 Prerequisites 章节
2. **违反单一职责**：例如做了多件事
3. **没有幂等性检查**：例如没有检查当前状态
4. **硬编码命令**：例如包含具体命令

#### 中优先级（建议修复）
1. **Description 不够清晰**：例如没有使用祈使句
2. **错误消息不完整**：例如缺少前置条件不满足的提示
3. **约束定义不明确**：例如没有说明不负责什么

#### 低优先级（可选优化）
1. **格式小问题**：例如标点符号不一致
2. **可以更简洁**：例如某些描述可以精简

### 💡 建议
提供具体的修改建议和代码示例

### 📋 总结
- ✅ **批准**：符合所有规范，可以合并
- ⚠️ **条件批准**：需要修复中/低优先级问题
- ❌ **拒绝**：存在高优先级问题，需要重新设计

---

## 🚀 快速 Review 提示词

使用以下提示词快速 review SKILL 文件：

```
请作为 Skill-Hub 专家，review 这个 SKILL.md 文件是否符合规范：

1. Frontmatter 是否完整（name, description, version, domain, action, object, type）
2. 是否包含必需章节（Trigger Conditions, Prerequisites, Execution Steps, Constraints）
3. 是否遵循单一职责原则
4. 是否有幂等性检查
5. 是否检查前置条件
6. 是否没有硬编码命令
7. 约束是否明确
8. 是否全部使用英文

请指出问题并提供修改建议。

SKILL 文件内容：
[粘贴 SKILL.md 内容]
```

---

## 📌 Skill-Hub 特定规则

### Domain 代码白名单
只允许以下 domain 代码：
- `sn` - ServiceNow
- `swc` - Software Center
- `env` - Environment Variables
- `nexus` - Nexus Artifact Repository
- `vpn` - VPN
- `hr` - HR System
- `doc` - Document System

### 命名格式
必须是 `{domain}-{action}-{object}` 格式，例如：
- ✅ `sn-request-software`
- ✅ `env-configure-java`
- ❌ `request-software` (缺少 domain)
- ❌ `configureJava` (格式错误)

### 参考文档
Review 时应参考：
- [Skill Design Principles](../docs/SKILL-DESIGN-PRINCIPLES.md)
- [Agent Skills Best Practices](../Agent-Skills-Best-Practices.md)
- [README](../README.md)

---

## 💡 Review 技巧

1. **先检查 Frontmatter**：确保所有必需字段存在且格式正确
2. **检查必需章节**：确保 4 个必需章节都存在
3. **验证单一职责**：问自己"这个 Skill 是否只做一件事？"
4. **查找硬编码**：搜索具体命令（如 `git config`, `npm install`）
5. **验证幂等性**：检查是否有"如果已配置则跳过"的逻辑
6. **检查前置条件**：确保有验证前置条件的步骤
7. **阅读 Constraints**：确保明确说明了不负责什么

---

## 🎯 Review 原则

- **建设性**：指出问题的同时提供解决方案
- **具体**：引用具体的章节和行号
- **平衡**：既指出问题，也肯定优点
- **高效**：优先关注高优先级问题
- **友好**：使用友好的语气

---

## 📖 参考资源

- 官方文档：https://agentskills.io
- Skill 创建最佳实践：https://agentskills.io/skill-creation/best-practices
- 优化描述：https://agentskills.io/skill-creation/optimizing-descriptions
