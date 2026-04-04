# Skill Design Principles

> **Core Philosophy**: Skills are operation manuals for AI Agents, not executable scripts.

## 1. Single Responsibility Principle

**One Skill = One System + One Action**

- ✅ `env-configure-maven` - Only configures MAVEN_HOME and PATH
- ❌ NOT configuring settings.xml (that's a different responsibility)
- ❌ NOT installing Maven (that's a prerequisite)

**Why**: AI can orchestrate multiple Skills. Each Skill should be atomic and reusable.

## 2. Idempotency Principle

**Check First, Configure Only If Needed**

Every Skill must:
1. Check current state before making changes
2. If already correctly configured → inform user and stop
3. Only configure if different from desired state

**Example Flow**:
```
Step 1: Verify prerequisites → Not met? Inform user and stop
Step 2: Check current state → Already correct? Inform user and stop
Step 3: Apply configuration → Only if needed
Step 4: Verify result
Step 5: Inform user
```

**Error Messages**:
- "Maven is not installed. Please install Maven first."
- "JAVA_HOME is not configured. Please use env-configure-java skill first."
- "npm registry is already set to {{url}}. No action needed."

## 3. No Hardcoding Principle

**Describe Intent, Not Commands**

Skills should guide AI to understand **what to do**, not **which exact command to run**.

**Bad (Hardcoded)**:
```markdown
Run: git config --global user.name "John Doe"
```

**Good (Intent-based)**:
```markdown
Set the global username that will appear in commits:
- Use the `user.name` configuration key
- Apply at global level
- If already configured correctly, skip this step (idempotent)
```

**Why**: 
- AI can adapt commands to different platforms
- AI can handle edge cases
- Commands may change, intent remains the same

## 4. Prerequisite Check Principle

**If Prerequisites Not Met, Inform User and Stop**

Do not attempt partial configuration. If a prerequisite is missing:
1. Clearly inform user what's missing
2. Suggest which Skill to use first
3. Stop execution

**Example**:
```markdown
### Step 1: Verify Prerequisites

- **Check if JAVA_HOME is set**: If not configured, inform user: 
  "JAVA_HOME is not configured. Please use env-configure-java skill first." 
  → **Stop and do not proceed.**
```

## 5. Clear Boundary Principle

**Explicitly State What Skill Is NOT Responsible For**

Every Skill must have a **Constraints** section that clearly defines boundaries:

**Example**:
```markdown
## Constraints

- **Single Responsibility**: Only configures environment variables. Does not configure settings.xml or repositories.
- **Idempotent**: Check first, configure only if needed.
- **Prerequisite Check**: If prerequisites are not met, inform user and stop.
- User-level environment variables only (no system-wide changes)
```

## 6. AI Empowerment Principle

**Let AI Do What AI Does Best**

Skills provide **atomic capabilities**, AI handles:
- **Context reasoning** - "You haven't applied for Java yet, let me submit the application first"
- **Autonomous orchestration** - "Install Java" involves 3 systems and 3 Skills, AI decides order
- **Exception handling** - Approval rejected? AI informs reason and suggests next steps
- **Personalized adaptation** - Same Skill, AI adjusts parameters based on user role

**Why**: Orchestration logic hardcoded in Skills limits flexibility. AI excels at dynamic decision-making.

## 7. Structured Format Principle

**Every Skill Follows the Same Structure**

```markdown
---
# Frontmatter with metadata
---
# Skill Name

## Purpose
Brief description (1-2 sentences)

## Trigger Conditions
When to use this Skill

## Prerequisites
What must be in place before using this Skill

## Execution Steps
Step-by-step guide with:
- Verification steps
- Idempotency checks
- Clear actions
- User notification

## Constraints
What this Skill is NOT responsible for

## Error Handling
Common errors and how to handle them

## Related Skills
Links to prerequisite or complementary Skills
```

## 8. User Communication Principle

**Clear, Actionable Messages**

Every Skill must inform users with:
- **Success confirmation** - "Maven environment variables have been configured successfully"
- **Next steps** - "You may need to restart your terminal for changes to take effect"
- **Verification guidance** - "Run `mvn --version` to verify the installation"
- **Error messages** - Specific, actionable, with suggestions

## Summary: Skill Design Checklist

Before publishing a Skill, verify:

- [ ] **Single Responsibility**: Does only one thing in one system
- [ ] **Idempotent**: Checks first, configures only if needed
- [ ] **No Hardcoding**: Describes intent, not specific commands
- [ ] **Prerequisite Check**: Informs user and stops if prerequisites not met
- [ ] **Clear Boundaries**: Explicitly states what it's NOT responsible for
- [ ] **AI Empowerment**: Leaves orchestration to AI
- [ ] **Structured Format**: Follows the standard template
- [ ] **User Communication**: Provides clear messages at every step
- [ ] **Pure English**: All content in English, no Chinese
