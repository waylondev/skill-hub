# SKILL File Review Rules

## Purpose

Review SKILL.md files to ensure compliance with Skill-Hub design principles and official specifications.

---

## Review Checklist

### 1. Frontmatter Validation

**Required Fields**:
- [ ] `name`: Skill name (required)
- [ ] `description`: Skill description (required)
- [ ] `version`: Version number (required)
- [ ] `displayName`: Display name (recommended)
- [ ] `domain`: Domain code (required)
- [ ] `action`: Action (required)
- [ ] `object`: Object (required)
- [ ] `type`: Type (required, value: SKILL)

**Naming Convention**:
- [ ] `name` follows `{domain}-{action}-{object}` format
- [ ] `domain` is valid (sn, swc, env, nexus, vpn, hr, doc)
- [ ] All lowercase with hyphens

**Description Quality**:
- [ ] Uses imperative "Use this skill when..."
- [ ] Focuses on user intent, not implementation details
- [ ] Lists applicable scenarios
- [ ] Concise (≤ 1024 characters)
- [ ] Includes trigger examples

**Example**:
```yaml
# Good
description: >-
  Use this skill when the user wants to configure Git, set up Git username,
  or configure Git email.

# Bad
description: >-
  This skill is used to configure git...  # Not imperative
```

---

### 2. Structure Validation

**Required Sections**:
- [ ] `## Trigger Conditions` - When to use
- [ ] `## Prerequisites` - Required state
- [ ] `## Execution Steps` - Operations
- [ ] `## Constraints` - Boundaries + idempotency

**Recommended**:
- [ ] `## Purpose` - Brief description (1-2 sentences)
- [ ] `## Error Handling` - Common errors

**Do NOT Include**:
- [ ] Related Skills list (AI discovers autonomously)
- [ ] Excessive optional examples
- [ ] Lengthy background explanations

---

### 3. Single Responsibility Principle

**Check**:
- [ ] Does only ONE thing (One Skill = One Action)
- [ ] Operates on ONE system only
- [ ] No hardcoded commands
- [ ] No orchestration logic

**Example**:
```markdown
Good: env-configure-maven - Only configures MAVEN_HOME and PATH

Bad: install-and-configure-java - Requests, installs, and configures (3 systems)
```

---

### 4. Idempotency

**Required**:
- [ ] Checks current state before modification
- [ ] If already configured, informs user and stops
- [ ] Only configures if needed

**Error Messages**:
- [ ] "XXX is not installed. Please install XXX first."
- [ ] "XXX is not configured. Please use XXX skill first."
- [ ] "XXX is already set to {{value}}. No action needed."

**Example Flow**:
```markdown
Step 1: Verify prerequisites → Not met? Inform and stop
Step 2: Check current state → Already correct? Inform and stop
Step 3: Apply configuration → Only if needed
Step 4: Verify result
Step 5: Inform user
```

---

### 5. Prerequisite Check

**Check**:
- [ ] Lists all prerequisites clearly
- [ ] If not met, informs user
- [ ] Suggests which Skill to use first
- [ ] Stops execution (no partial configuration)

**Example**:
```markdown
### Step 1: Verify Prerequisites

- **Check if JAVA_HOME is set**: If not configured, inform user: 
  "JAVA_HOME is not configured. Please use env-configure-java skill first." 
  → **Stop and do not proceed.**
```

---

### 6. No Hardcoding Principle

**Check**:
- [ ] Describes intent, not specific commands
- [ ] No hardcoded commands (e.g., `git config --global user.name`)
- [ ] Allows AI to adapt to different platforms
- [ ] Uses intent descriptions

**Example**:
```markdown
Bad (Hardcoded):
Run: git config --global user.name "John Doe"

Good (Intent-based):
Set the global username that will appear in commits:
- Use the `user.name` configuration key
- Apply at global level
- If already configured correctly, skip this step (idempotent)
```

---

### 7. Constraints and Boundaries

**Must Specify**:
- [ ] What this Skill is NOT responsible for
- [ ] Operation level (user vs system)
- [ ] Idempotency statement
- [ ] Prerequisite check statement

**Example**:
```markdown
## Constraints

- **Single Responsibility**: Only configures environment variables. Does not configure settings.xml or repositories.
- **Idempotent**: Check first, configure only if needed.
- **Prerequisite Check**: If prerequisites are not met, inform user and stop.
- **User-level only**: Only modifies user environment variables (no system-wide changes).
```

---

### 8. User Communication

**Check**:
- [ ] Success confirmation message
- [ ] Next steps guidance
- [ ] Verification instructions
- [ ] Clear, actionable error messages

**Example Messages**:
```markdown
- "Maven environment variables have been configured successfully"
- "You may need to restart your terminal for changes to take effect"
- "Run `mvn --version` to verify the installation"
- "Maven is not installed. Please install Maven first."
```

---

### 9. Language Check

**Check**:
- [ ] All content in English (Pure English)
- [ ] No Chinese or other languages
- [ ] Grammar is correct
- [ ] Clear, professional language

---

### 10. AI Empowerment

**Check**:
- [ ] Orchestration left to AI
- [ ] AI handles context reasoning
- [ ] AI handles exceptions
- [ ] Provides atomic capabilities, not complete workflows

---

## Review Output Format

### Strengths
List what the SKILL file does well

### Needs Improvement

#### High Priority (Must Fix)
1. **Missing required sections**: e.g., no Prerequisites section
2. **Violates single responsibility**: e.g., does multiple things
3. **No idempotency check**: e.g., no state checking
4. **Hardcoded commands**: e.g., specific git commands

#### Medium Priority (Recommended)
1. **Unclear description**: e.g., not using imperative
2. **Incomplete error messages**: e.g., missing prerequisite failure messages
3. **Unclear constraints**: e.g., doesn't state what it's not responsible for

#### Low Priority (Optional)
1. **Minor formatting issues**: e.g., inconsistent punctuation
2. **Could be more concise**: e.g., verbose descriptions

### Suggestions
Provide specific improvement suggestions with code examples

### Summary
- **Approve**: Complies with all standards, ready to merge
- **Conditional Approval**: Needs medium/low priority fixes
- **Reject**: Has high priority issues, needs redesign

---

## Quick Review Prompts

Use these prompts for quick SKILL file review:

### Full Review
```
As a Skill-Hub expert, review this SKILL.md file for compliance:

1. Frontmatter complete and correct (name, description, version, domain, action, object, type)
2. Required sections present (Trigger Conditions, Prerequisites, Execution Steps, Constraints)
3. Single responsibility principle followed
4. Idempotency implemented
5. Prerequisite checks present
6. No hardcoded commands
7. Constraints clearly defined
8. All in English

Identify issues and provide fix suggestions.

SKILL file content:
[paste SKILL.md content]
```

### Quick Check
```
Quick check for obvious issues in this SKILL.md:
- Missing required sections
- Violates single responsibility
- Hardcoded commands
- No idempotency
- Not all in English

SKILL file:
[paste content]
```

### Specific Checks

**Frontmatter**:
```
Check Frontmatter compliance:
- name follows {domain}-{action}-{object}
- domain is valid (sn, swc, env, nexus, vpn, hr, doc)
- description uses "Use this skill when..."
- description focuses on user intent
- all required fields present

Frontmatter:
[paste frontmatter]
```

**Idempotency**:
```
Check idempotency implementation:
- Checks current state before modification
- If already configured, informs and stops
- Only configures if needed
- Error messages follow pattern

Execution Steps:
[paste steps]
```

**Prerequisites**:
```
Check prerequisite handling:
- Lists all prerequisites
- Informs user if not met
- Suggests which Skill to use first
- Stops execution

Prerequisites section:
[paste section]
```

**Hardcoding**:
```
Check for hardcoded commands:
- Look for specific commands (git config, npm install, etc.)
- Look for specific paths
- Should use intent descriptions instead

Execution Steps:
[paste steps]
```

**Constraints**:
```
Check Constraints section:
- States what Skill is NOT responsible for
- Idempotency statement
- Prerequisite check statement
- Operation level

Constraints:
[paste section]
```

---

## Review Principles

- **Constructive**: Provide solutions with problems
- **Specific**: Reference specific sections and line numbers
- **Balanced**: Acknowledge strengths and weaknesses
- **Efficient**: Focus on high-priority issues first
- **Friendly**: Use friendly, professional tone

---

## Domain Code Whitelist

Only these domain codes are allowed:
- `sn` - ServiceNow
- `swc` - Software Center
- `env` - Environment Variables
- `nexus` - Nexus Artifact Repository
- `vpn` - VPN
- `hr` - HR System
- `doc` - Document System

---

## Reference Documents

- [Skill Design Principles](../docs/SKILL-DESIGN-PRINCIPLES.md)
- [Agent Skills Best Practices](../Agent-Skills-Best-Practices.md)
- [README](../README.md)
- Official docs: https://agentskills.io

---

## Design Principles Applied

This review guide follows:

- **SOLID**: Single responsibility, clear boundaries
- **KISS**: Keep it simple, focus on essentials
- **DRY**: Don't repeat, reference official docs
- **Atomic**: Each check is independent
- **Intent-based**: Describe what to check, not how
