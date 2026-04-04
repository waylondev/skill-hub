# Skill-Hub

> **Turn Confluence theoretical knowledge into AI execution capabilities**
>
> Confluence tells you how, Skill-Hub lets AI do it for you.

## Core Value

Transform internal repetitive process knowledge into AI-executable operational capabilities:

- **Knowledge Form**: From document reading → Structured instructions
- **Operation Mode**: From manual operation → AI automated execution
- **Efficiency Boost**: Complete multi-system operations with one sentence

## Usage

Skills in Skill-Hub are operation manuals for AI models to call, not programs to execute directly.

### AI Model Calling Process

1. **User Input**: "Help me install Java"
2. **AI Intent Understanding**: Matches relevant Skills
3. **AI Reads Skill Content**: Understands specific operation steps
4. **AI Autonomous Execution**: Operates corresponding systems step by step

### Example: AI Execution Flow for Installing Java

```
User: "Help me install Java"
→ AI matches: sn-request-software, swc-install-package, env-configure-java
→ AI reads each Skill's operation steps
→ AI executes in sequence: Request software → Wait approval → Install → Configure environment
→ Fully automated, no human intervention needed
```

## Core Skill List

| Category | Skill | Function |
|----------|-------|----------|
| **ServiceNow** | `sn-request-software` | Request software installation |
| **ServiceNow** | `sn-request-ad-group` | Request permissions |
| **Software Center** | `swc-install-package` | Install software |
| **Environment** | `env-configure-java` | Configure Java environment |
| **Environment** | `env-configure-nodejs` | Configure Node.js environment |
| **Environment** | `env-configure-python` | Configure Python environment |
| **Environment** | `env-configure-maven` | Configure Maven environment |
| **Environment** | `env-configure-path` | Configure environment variable paths |

## Skill Design Principles

All Skills follow these core principles:

1. **Single Responsibility** - One Skill = One System + One Action
2. **Idempotency** - Check first, configure only if needed
3. **No Hardcoding** - Describe intent, not commands
4. **Prerequisite Check** - Inform user and stop if prerequisites not met
5. **Clear Boundaries** - Explicitly state what Skill is NOT responsible for
6. **AI Empowerment** - Let AI handle orchestration and exceptions
7. **Structured Format** - Consistent template across all Skills
8. **User Communication** - Clear, actionable messages at every step

See [Skill Design Principles](./docs/SKILL-DESIGN-PRINCIPLES.md) for detailed guidelines.

## Contribution Guide

1. Write `SKILL.md` (refer to [Skill Design Principles](./docs/SKILL-DESIGN-PRINCIPLES.md))
2. Run `skill push ./skills/your-skill`
3. Submit PR for merging

## Documentation

- [Product Requirements Document](./docs/Skill-Hub-PRD.md) - Complete PRD with architecture, standards, and implementation plan
- [Skill Design Principles](./docs/SKILL-DESIGN-PRINCIPLES.md) - Detailed guidelines for creating Skills
