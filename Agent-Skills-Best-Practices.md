# Agent Skills Best Practices

> Based on [Agent Skills Official Documentation](https://agentskills.io) industry standards
>
> **Reference Documents**:
> - https://agentskills.io/home
> - https://agentskills.io/what-are-skills
> - https://agentskills.io/skill-creation/best-practices
> - https://agentskills.io/skill-creation/optimizing-descriptions

---

## 1. Skill Description Optimization Principles

### 1.1 Use Imperative Phrasing

**✅ Recommended**:
```yaml
description: >-
  Use this skill when the user wants to configure Git, set up Git username, or configure Git email.
```

**❌ Avoid**:
```yaml
description: >-
  This skill is used when the user requests "configure Git", "set Git username".
```

### 1.2 Focus on User Intent, Not Implementation Details

Descriptions should focus on **what the user wants to achieve**, not how the Skill works internally.

**✅ Recommended**:
- "Use this skill when the user wants to configure npm mirror"
- "Use this skill when the user wants to request software installation"

**❌ Avoid**:
- "This skill calls ServiceNow API to submit applications"
- "This skill modifies .npmrc file"

### 1.3 Explicitly List Applicable Scenarios

Actively list contexts where the Skill applies, even if users don't explicitly mention relevant keywords.

**Example**:
```yaml
description: >-
  Use this skill when the user wants to configure npm mirror, set up .npmrc,
  or configure internal Nexus npm registry, even if they don't explicitly mention "npm" or "registry".
```

### 1.4 Keep It Concise

- Length: A few sentences to a short paragraph
- Enough to cover Skill scope
- Short enough not to bloat context across multiple Skills
- Official recommendation: ≤ 1024 characters

---

## 2. Skill Design Core Principles

### 2.1 Atomic Capabilities

One Skill only does **one thing**, only operates **one system**.

**✅ Good Skills**:
- `sn-request-software` - Only request software in ServiceNow
- `env-configure-java` - Only configure Java environment variables
- `swc-install-package` - Only install in Software Center

**❌ Bad Skills**:
- `install-and-configure-java` - Requests, installs, and configures (crosses 3 systems)

### 2.2 No Orchestration

**Orchestration is AI Agent's responsibility**, Skills absolutely do not orchestrate.

**Why?**
- AI understands context, judges preconditions, handles exceptions
- Predefined orchestration logic can't adapt to different scenarios
- Atomic Skills can be freely combined by AI, higher reusability

**Example**: User says "I want to install Java"
- ❌ Skill internally hardcodes: Request → Install → Configure
- ✅ AI autonomously orchestrates: `sn-request-software` → `swc-install-package` → `env-configure-java`

### 2.3 Single Responsibility

Follow SOLID single responsibility principle, one Skill only responsible for one operation in one system.

### 2.4 Idempotency

Same input executed multiple times, consistent results.

**Explicitly state in constraints**:
```markdown
## Constraints
- Idempotent: check if correctly configured if already set, do not reconfigure
```

### 2.5 No Tool Wrapping

Skills focus on **internal process knowledge**, don't teach Agent how to use CLI.

**✅ Skills should contain**:
- Internal portal addresses
- Approval chains
- Specified versions
- Company-specific configurations

**❌ Skills should NOT contain**:
- "Teach you how to use git config"
- "Teach you how to use npm install"

---

## 3. SKILL.md Structure

### 3.1 Frontmatter

```yaml
---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git, set up Git username,
  or configure Git email.
version: 1.0.0
displayName: Configure Git
domain: env
action: configure
object: git
tags: [env, git, scm, config]
type: SKILL
inputs:
  - name: user_name
    type: string
    required: true
    description: Git username
  - name: user_email
    type: string
    required: true
    description: Git email
---
```

### 3.2 Body Recommended Structure

| Section | Purpose | Required |
|---------|---------|----------|
| `## Trigger Conditions` | When to use | ✅ |
| `## Prerequisites` | Dependent system state | ✅ |
| `## Execution Steps` | Specific operations | ✅ |
| `## Constraints` | Boundaries + idempotency | ✅ |

**Not recommended to include**:
- Related Skill lists (AI will discover autonomously)
- Too many optional configuration examples
- Lengthy background explanations

---

## 4. Naming Conventions

Format: `{domain}-{action}-{object}`

**Domain Codes**:
- `sn` - ServiceNow
- `swc` - Software Center
- `env` - Environment Variables
- `nexus` - Nexus Artifact Repository
- `vpn` - VPN
- `hr` - HR System
- `doc` - Document System

**Examples**:
- `sn-request-software` - ServiceNow request software
- `swc-install-package` - Software Center install package
- `env-configure-java` - Environment configure Java

---

## 5. Skill Trigger Evaluation

### 5.1 Should-Trigger Queries

Test scenarios where Skill should trigger:
- Formal and informal phrasing
- Typos or abbreviations
- Directly mention Skill domain or indirectly describe needs
- Mix of concise prompts and detailed context
- Single-step and multi-step workflows

**Examples**:
- "Configure Git for me"
- "Set up my Git username and email"
- "I need to configure Git before I commit"

### 5.2 Should-Not-Trigger Queries

Test scenarios where Skill should NOT trigger:
- Obviously irrelevant (for testing boundaries)
- Share concepts but need different operations
- Involve keywords but different tasks

**Examples**:
- "Install Git" (install vs configure)
- "Commit my code" (use Git vs configure Git)

---

## 6. Optimization Loop

1. Evaluate current description on train and validation sets
2. Identify failures in train set
3. Revise description:
   - If should-trigger queries fail: broaden scope
   - If should-not-trigger queries misfire: add specificity
4. Check description stays within 1024 character limit
5. Repeat until train set passes or no meaningful improvement
6. Select version with highest validation pass rate

---

## 7. Quick Checklist

Before creating a new Skill, confirm:

- [ ] Description uses imperative "Use this skill when..."
- [ ] Description focuses on user intent, not implementation details
- [ ] Description is concise (≤ 1024 characters)
- [ ] Skill only does one thing (atomic capability)
- [ ] Skill does not orchestrate
- [ ] Skill only operates one system
- [ ] Constraints explicitly state idempotency
- [ ] Naming follows `{domain}-{action}-{object}` format
- [ ] Contains internal-specific knowledge (addresses, approval chains, etc.)
- [ ] Does not wrap general CLI tools
