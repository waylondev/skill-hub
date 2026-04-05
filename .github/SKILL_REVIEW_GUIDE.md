# SKILL Review 使用指南

## 📁 文件说明

本项目包含两个 Review 规则文件：

1. **[SKILL_REVIEW_RULES.md](./.github/SKILL_REVIEW_RULES.md)** - 完整的 SKILL 文件审查规则
2. **[skill-review.code-snippets](./.vscode/skill-review.code-snippets)** - VSCode 代码片段

---

## 🚀 使用方法

### 方法 1：使用 VSCode 代码片段（推荐）

在 VSCode 中打开任何文件，输入以下代码片段前缀：

#### 完整 Review
```
skillreview + Tab
```
插入完整的 SKILL review 提示词，包含 10 个检查维度。

#### 快速检查
```
skillquickreview + Tab
```
快速检查主要问题。

#### 专项检查
- `skillreviewfrontmatter` - 检查 Frontmatter
- `skillreviewidempotent` - 检查幂等性
- `skillreviewprereq` - 检查前置条件
- `skillreviewhardcode` - 检查硬编码命令
- `skillreviewconstraints` - 检查 Constraints 章节

**操作步骤**：
1. 打开要 review 的 SKILL.md 文件
2. 全选复制（Ctrl+A, Ctrl+C）
3. 在 Trae/AI 对话框中输入代码片段前缀 + Tab
4. 粘贴 SKILL 内容
5. 发送

---

### 方法 2：复制规则文件内容

打开 [SKILL_REVIEW_RULES.md](./.github/SKILL_REVIEW_RULES.md)，复制相关章节到 AI 对话框。

**示例**：
```
请按照 SKILL_REVIEW_RULES.md 的规则 review 这个 SKILL 文件：

[粘贴 SKILL.md 内容]
```

---

### 方法 3：使用快速 Review 提示词

```
请作为 Skill-Hub 专家，review 这个 SKILL.md 文件：

1. Frontmatter 是否完整且格式正确
2. 是否包含 4 个必需章节
3. 是否遵循单一职责原则
4. 是否有幂等性检查
5. 是否检查前置条件
6. 是否没有硬编码命令
7. 约束是否明确
8. 是否全部使用英文

请指出问题并提供修改建议。

SKILL 文件：
[粘贴内容]
```

---

## 📋 Review 检查清单

### 高优先级问题（必须修复）

- ❌ 缺少必需章节（Trigger Conditions, Prerequisites, Execution Steps, Constraints）
- ❌ 违反单一职责（一个 Skill 做多件事）
- ❌ 没有幂等性检查（不检查当前状态直接修改）
- ❌ 硬编码具体命令
- ❌ 没有前置条件检查
- ❌ 包含中文内容

### 中优先级问题（建议修复）

- ⚠️ Frontmatter 字段不完整
- ⚠️ Description 没有使用祈使句
- ⚠️ 错误消息不规范
- ⚠️ Constraints 定义不明确
- ⚠️ 缺少 Purpose 或 Error Handling 章节

### 低优先级问题（可选优化）

- 💡 格式小问题
- 💡 描述可以更简洁
- 💡 示例不够充分

---

## 💡 实际使用示例

### 示例 1：Review 新的 SKILL 文件

**场景**：提交了新的 SKILL.md 文件

**操作**：
1. 在 PR 中查看变更的 SKILL.md
2. 复制文件内容
3. 在 AI 对话框输入 `skillreview` + Tab
4. 粘贴内容，发送

**AI 会检查**：
- Frontmatter 格式
- 必需章节完整性
- 单一职责原则
- 幂等性实现
- 前置条件检查
- 硬编码问题
- 约束定义
- 语言使用

---

### 示例 2：检查 Frontmatter

**场景**：不确定 Frontmatter 是否规范

**操作**：
```
skillreviewfrontmatter + Tab
```
粘贴 Frontmatter 部分，发送

**AI 会检查**：
- name 格式是否为 {domain}-{action}-{object}
- domain 是否是有效代码
- description 是否使用祈使句
- 必需字段是否完整

---

### 示例 3：检查幂等性

**场景**：确保 Skill 具有幂等性

**操作**：
```
skillreviewidempotent + Tab
```
粘贴 Execution Steps 部分，发送

**AI 会检查**：
- 是否检查当前状态
- 已配置时是否跳过
- 错误消息是否规范

---

### 示例 4：检查硬编码

**场景**：确保没有硬编码命令

**操作**：
```
skillreviewhardcode + Tab
```
粘贴 Execution Steps 部分，发送

**AI 会查找**：
- 具体命令（如 `git config --global ...`）
- 具体路径
- 应该用意图描述替代的地方

---

## 🎯 Review 流程建议

### 提交前自检流程

1. **写完后立即 review**
   ```
   skillquickreview → 快速检查主要问题
   ```

2. **针对性检查**
   ```
   skillreviewfrontmatter → 检查 Frontmatter
   skillreviewidempotent → 检查幂等性
   skillreviewprereq → 检查前置条件
   skillreviewhardcode → 检查硬编码
   skillreviewconstraints → 检查 Constraints
   ```

3. **最终全面 review**
   ```
   skillreview → 全面检查所有维度
   ```

4. **根据 AI 反馈修改**

5. **再次 review 确认修复**

---

### PR Review 流程

1. **打开 PR 变更**
2. **对每个 SKILL.md 变更**：
   ```
   skillreview → 全面检查
   ```
3. **复制 AI 的 review 结果到 PR 评论**
4. **等待作者修复**
5. **修复后再次 review**
6. **批准后合并**

---

## 📊 Review 输出示例

### ✅ 批准示例

```
✅ **优点**
- Frontmatter 完整，格式正确
- Description 使用祈使句，清晰描述用户意图
- 4 个必需章节完整
- 严格遵循单一职责原则
- 幂等性实现完善，有检查当前状态的逻辑
- 前置条件检查清晰，告知用户正确的操作步骤
- 没有硬编码命令，使用意图描述
- Constraints 明确说明了边界
- 全部使用英文，语法正确

⚠️ **需要改进**
无高优先级问题

💡 **建议**
- 可以添加 Error Handling 章节，提供更详细的错误处理指导（低优先级）

📋 **总结**
✅ **批准** - 符合所有 Skill-Hub 规范，可以合并
```

---

### ⚠️ 条件批准示例

```
✅ **优点**
- Frontmatter 基本完整
- 包含了必需的 4 个章节
- 遵循单一职责原则

⚠️ **需要改进**

**中优先级**：
1. Description 没有使用祈使句
   - 当前："This skill is used to configure..."
   - 建议："Use this skill when the user wants to configure..."

2. 幂等性检查不完整
   - 没有"如果已配置则跳过"的逻辑
   - 建议添加：检查当前状态，如果正确则告知用户并停止

3. Constraints 不够明确
   - 没有说明不负责什么
   - 建议添加：明确说明只做配置，不负责安装或验证

💡 **建议**
修改以上 3 个问题后可以合并

📋 **总结**
⚠️ **条件批准** - 需要修复中优先级问题
```

---

### ❌ 拒绝示例

```
✅ **优点**
- 意图是好的，想提供一个完整的解决方案

⚠️ **需要改进**

**高优先级**：
1. 违反单一职责原则
   - 这个 Skill 做了 3 件事：请求、安装、配置
   - 应该拆分为 3 个独立的 Skill

2. 硬编码具体命令
   - 包含 "Run: git config --global user.name ..."
   - 应该使用意图描述

3. 没有前置条件检查
   - 没有检查 Git 是否已安装
   - 没有检查前置 Skill 是否已应用

4. 包含中文内容
   - 第 15 行有中文说明
   - 应该全部使用英文

**中优先级**：
1. Frontmatter 缺少 type 字段
2. 缺少 Constraints 章节

💡 **建议**
重新设计这个 Skill：
1. 拆分为 3 个独立的 Skill
2. 移除所有硬编码命令
3. 添加前置条件检查
4. 全部使用英文
5. 添加完整的 Frontmatter 和 Constraints

📋 **总结**
❌ **拒绝** - 存在多个高优先级问题，需要重新设计
```

---

## 🔧 自定义规则

如果需要调整 review 规则，可以：

1. **修改规则文件**：编辑 `.github/SKILL_REVIEW_RULES.md`
2. **添加新的代码片段**：编辑 `.vscode/skill-review.code-snippets`
3. **创建项目特定规则**：在规则文件中添加新的检查项

---

## 📖 参考资源

- [Skill Design Principles](../docs/SKILL-DESIGN-PRINCIPLES.md)
- [Agent Skills Best Practices](../Agent-Skills-Best-Practices.md)
- [README](../README.md)
- 官方文档：https://agentskills.io

---

## 💬 常见问题

### Q: 为什么要检查这么多项？

A: Skill 是 AI 的执行手册，质量直接影响 AI 的执行效果。严格的规范确保：
- AI 能正确理解何时使用
- AI 能按正确步骤执行
- 不会出现意外行为
- 所有 Skill 风格一致

### Q: 如果 AI review 错了怎么办？

A: AI review 是辅助工具，最终由人决定。如果 AI 错了：
- 可以忽略不正确的建议
- 可以调整提示词，让 AI 更准确
- 可以修改规则文件，更新检查标准

### Q: 需要每次都做全面 review 吗？

A: 不需要。建议：
- 新 Skill：全面 review
- 小修改：快速 review 或专项检查
- 文档修订：可以不 review

### Q: 如何确保 AI review 的一致性？

A: 使用相同的规则文件和代码片段，确保：
- 所有 reviewer 使用相同的标准
- 使用代码片段插入完整的提示词
- 参考相同的规范文档

---

**Happy Reviewing!** 🎉
