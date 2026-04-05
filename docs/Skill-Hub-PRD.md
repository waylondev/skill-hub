# Skill-Hub Product Requirements Document (PRD) v3.4

> **Version**: v3.4 | **Date**: 2026-04-04  
> **Core Positioning**: Turn theoretical knowledge into AI execution capabilities
>
> **Skill Standards**: This project follows [Skill Design Principles](./SKILL-DESIGN-PRINCIPLES.md)

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Architecture](#2-architecture)
- [3. Skill Definition Standards](#3-skill-definition-standards)
- [4. Naming Conventions](#4-naming-conventions)
- [5. CLI Tool](#5-cli-tool)
- [6. Repository Structure](#6-repository-structure)
- [7. Showcase Site](#7-showcase-site)
- [8. Implementation Plan](#8-implementation-plan)
- [9. Initial Skill List](#9-initial-skill-list)

---

## 1. Project Overview

### 1.1 Problem: Knowledge "Sleeps" in Documentation

Organizations have numerous **internal-only repetitive processes**:

- New employees need to apply for VPN, Jenkins, ServiceNow, IKP, Vault, G3 permissions
- Installing software requires ServiceNow requests, approval, Software Center installation, environment configuration
- Configuring Maven/Node requires internal Nexus mirrors
- Accessing internal systems requires following specific procedures

**Current State**: Knowledge scattered across documentation (Confluence, wikis, guides) and senior employees' minds.

**Core Issue**: Documentation is a **theoretical knowledge base**—you read, understand, then **do it yourself**. Every time: search docs → understand process → open systems → follow steps. Knowledge stays at "read" stage, never becoming "executed" capability.

**Example - Confluence Scenario**:
```
Confluence Page: "How to Install Java"
1. Submit ServiceNow request (link to form)
2. Wait for approval (1-2 business days)
3. Install via Software Center
4. Configure JAVA_HOME environment variable

Problem: Every employee reads this page and manually executes all 4 steps.
Waste: 30 minutes per employee × hundreds of employees = massive productivity loss
```

### 1.2 Solution: Let AI Do the Work

Skill-Hub transforms **theoretical knowledge** into **operational capabilities** that AI Agents can directly execute:

> **Documentation tells you how, Skill-Hub lets AI do it for you.**

- **One Git repository** (`skill-hub`) - stores all Skills
- **One CLI tool** (5 commands) - manages Skills
- **One showcase site** - promotes available Skills

**Core Value**: Employees say one sentence, AI Agent automatically completes all work that required searching docs, running processes, and operating systems.

**Example - After Skill-Hub**:
```
User: "Help me install Java"
→ AI reads Skills: sn-request-software, swc-install-package, env-configure-java
→ AI executes automatically:
  1. Submits ServiceNow request
  2. Monitors approval status
  3. Installs via Software Center
  4. Configures JAVA_HOME
→ Result: Java installed and configured, zero manual steps
Savings: 30 minutes → 0 minutes per employee
```

### 1.3 Why AI?

Skills are **atomic operation manuals**; AI creates value through:

| AI Characteristic | Significance |
|-------------------|-------------|
| **Natural Language Understanding** | Employees say "help me install Java", AI parses intent |
| **Context Reasoning** | AI judges preconditions - "You haven't applied for Java yet" |
| **Autonomous Orchestration** | AI decides execution order across multiple Skills |
| **Exception Handling** | AI informs rejection reasons and suggests next steps |
| **Continuous Learning** | New Skill added, all employees can use immediately |

**This is why Skills only provide atomic capabilities, not orchestration**—orchestration is what AI does best.

### 1.4 What is a Skill?

A Skill is a **structured natural language description** documenting the complete execution method of an operation in **a specific system**.

**What Skill is NOT**:
- ❌ Not a CLI tool wrapper
- ❌ Not an API call encapsulation
- ❌ Not code
- ❌ **Not process orchestration**—orchestration is AI Agent's job

**What Skill IS**:
- ✅ **One system + One action**—atomic capability, indivisible
- ✅ **Internal-only operational knowledge**—which portal, approval chain, internal address
- ✅ **High-frequency repetitive operations**—what every employee does repeatedly
- ✅ **Bridge from "reading docs" to "doing for you"**
- ✅ **Any reusable knowledge**—Confluence, wikis, guides, tribal knowledge, best practices

**Sources of Skills** (with Confluence as primary example):
- **Confluence** (most common) - Transform existing process docs into Skills
- **Internal wikis and guides** - Any documentation platform
- **Standard operating procedures (SOPs)** - Formal process documents
- **IT policies and processes** - Compliance and governance workflows
- **Senior employees' tribal knowledge** - Capture expertise before retirement
- **Best practices and playbooks** - Repeatable success patterns

**Confluence Example**:
```
Before: Confluence page "How to Request AD Group Access" (read-only)
After:  Skill `sn-request-ad-group` (AI-executable)

Benefit: Instead of reading and manually executing, 
         user says "I need access to prod-deploy group" 
         and AI handles the entire request process.
```

### 1.5 Skill Granularity

**One Skill = One Operation in One System**. Skills absolutely do not orchestrate.

**Why Skills Don't Orchestrate**:
- Orchestration requires understanding context, judging preconditions, handling exceptions—AI excels at this
- Hardcoded orchestration in Skills can't adapt to different scenarios
- AI can reuse atomic Skills flexibly; hardcoded orchestration limits reusability

**Example**: "Install Java" involves:
1. `sn-request-software` - Submit ServiceNow request
2. Wait for approval (AI monitors status)
3. `swc-install-package` - Install via Software Center
4. `env-configure-java` - Configure environment variables

One Skill only covers **one step**. AI orchestrates all steps.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Employee (User)                       │
│              Natural language input:                     │
│           "Help me install Java"                         │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    AI Agent                              │
│  - Understands intent                                    │
│  - Matches relevant Skills                               │
│  - Reads Skill execution steps                           │
│  - Orchestrates multi-Skill execution                    │
│  - Handles exceptions and edge cases                     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              Skill-Hub Repository                        │
│  skills/                                                 │
│  ├── sn-request-software/SKILL.md  ← AI reads this      │
│  ├── swc-install-package/SKILL.md  ← AI reads this      │
│  └── env-configure-java/SKILL.md   ← AI reads this      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              External Systems                            │
│  ServiceNow → Software Center → Environment Variables   │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Skill Definition Standards

### 3.1 File Structure

Each Skill is a `SKILL.md` file containing:

```markdown
---
name: skill-name
description: Brief description for AI matching
version: 1.0.0
displayName: Human-readable name
domain: domain-code
action: action
object: object
tags: [tag1, tag2]
inputs:
  - name: param_name
    type: string
    required: true
    description: Parameter description
---
# Skill Name

## Purpose
Brief description (1-2 sentences)

## Trigger Conditions
When to use this Skill

## Prerequisites
What must be in place before using this Skill

## Execution Steps
Step-by-step guide with verification and idempotency checks

## Constraints
What this Skill is NOT responsible for

## Error Handling
Common errors and how to handle them

**Note**: Do NOT include "Related Skills" section - AI will discover related skills autonomously.
```

### 3.2 Design Principles

All Skills must follow these principles (see [SKILL-DESIGN-PRINCIPLES.md](./SKILL-DESIGN-PRINCIPLES.md)):

1. **Single Responsibility** - One Skill = One System + One Action
2. **Idempotency** - Check first, configure only if needed
3. **No Hardcoding** - Describe intent, not commands
4. **Prerequisite Check** - Inform user and stop if prerequisites not met
5. **Clear Boundaries** - Explicitly state what Skill is NOT responsible for
6. **AI Empowerment** - Let AI handle orchestration
7. **Structured Format** - Consistent template
8. **User Communication** - Clear, actionable messages
9. **Pure English** - All content in English

### 3.3 Example Skill

```markdown
---
name: env-configure-maven
description: Configure Maven environment variables (MAVEN_HOME and PATH)
version: 1.0.0
displayName: Configure Maven Environment Variables
domain: env
action: configure
object: maven
tags: [env, maven, java, config]
inputs:
  - name: maven_home
    type: string
    required: false
    description: Maven installation path
---
# Configure Maven Environment Variables

## Purpose
Configure Maven environment variables (MAVEN_HOME and PATH) only.

## Trigger Conditions
- Maven is installed and needs MAVEN_HOME
- User needs to add Maven to PATH

## Prerequisites
- Maven is installed
- JAVA_HOME is configured

## Execution Steps

### Step 1: Verify Prerequisites
- Check if Maven is installed
- Check if JAVA_HOME is configured
- If not met, inform user and stop

### Step 2: Check Current Configuration
- Check if MAVEN_HOME already set correctly
- Check if Maven bin already in PATH
- If already configured, inform user and stop

### Step 3: Set MAVEN_HOME
- Configure user-level environment variable

### Step 4: Add to PATH
- Add Maven bin to PATH

### Step 5: Verify and Inform
- Verify configuration
- Inform user of success

## Constraints
- Only configures environment variables
- Does not configure settings.xml
- Idempotent
- User-level only

## Error Handling
- Maven not installed: "Maven is not installed. Please install first."
- JAVA_HOME not set: "Use env-configure-java skill first."
- Already configured: "Already configured correctly. No action needed."
```

---

## 4. Naming Conventions

### 4.1 Skill Name Format

```
{domain}-{action}-{object}
```

**Examples**:
- `sn-request-software` - ServiceNow request software
- `swc-install-package` - Software Center install package
- `env-configure-java` - Environment configure Java

### 4.2 Domain Codes

| Domain | System | Example |
|--------|--------|---------|
| `sn` | ServiceNow | `sn-request-software` |
| `swc` | Software Center | `swc-install-package` |
| `env` | Environment Variables | `env-configure-java` |
| `nexus` | Nexus Repository | `nexus-configure-maven` |
| `vpn` | VPN | `vpn-apply-permission` |

**Rules**: Lowercase English, hyphens, ≤40 chars total.

---

## 5. CLI Tool

### 5.1 Commands

| Command | Description | Example |
|---------|-------------|---------|
| `skill search <keyword>` | Search Skills | `skill search java` |
| `skill install <name>` | Install locally | `skill install sn-request-software` |
| `skill uninstall <name>` | Uninstall | `skill uninstall sn-request-software` |
| `skill read <name>` | Read skill content for AI | `skill read sn-request-software` |
| `skill push <path>` | Publish | `skill push ./skills/xxx` |

### 5.2 Implementation

**Tech Stack**:
- Go + Cobra (industry standard: kubectl, docker, gh use it)
- Viper for configuration
- Go-git for Git operations
- Pterm for terminal UI
- Goreleaser for multi-platform builds

---

## 6. Repository Structure

```
skill-hub/
├── skills/
│   ├── sn-request-software/SKILL.md
│   ├── swc-install-package/SKILL.md
│   └── env-configure-java/SKILL.md
├── registry.yaml (auto-generated)
├── domains.yaml
├── README.md
├── SKILL-DESIGN-PRINCIPLES.md
└── Skill-Hub-PRD.md
```

### Release Process

```
Write SKILL.md → skill push → Auto validate → Submit PR → Review → Merge → CI updates index → Showcase auto-builds
```

---

## 7. Showcase Site

**Tech**: Astro + Pagefind + GitHub Pages

**Features**:
- Search with Chinese keyword support
- Filter by domain/tag
- Top Skills by usage frequency
- One-click copy install/run commands
- Category browsing by domain

---

## 8. Implementation Plan

### Phase 1: Repository Foundation (Week 1-2)

**Tasks**:
1. Initialize Git repository
2. Create directory structure
3. Create domains.yaml
4. Write 3 example Skills:
   - `sn-request-software`
   - `swc-install-package`
   - `env-configure-java`
5. Generate registry.yaml

**Acceptance**: Git repo with 3 compliant Skills + domains.yaml + registry.yaml

### Phase 2: CLI Tool (Week 3-5)

**Tasks**:
1. Initialize Go project with Cobra
2. Implement SKILL.md parser
3. Implement validator
4. Implement 5 commands:
   - search
   - install
   - uninstall
   - run
   - push

**Acceptance**: All 5 commands functional

### Phase 3: Showcase Site (Week 6-7)

**Tasks**:
1. Initialize Astro project
2. Build homepage with search
3. Build Skill detail pages
4. Set up CI/CD with GitHub Pages

**Acceptance**: Site accessible, all Skills visible, search works

---

## 9. Initial Skill List

| Skill | Description |
|-------|-------------|
| `sn-request-software` | Request software via ServiceNow |
| `sn-request-ad-group` | Request AD group permissions |
| `swc-install-package` | Install software via Software Center |
| `env-configure-java` | Configure Java environment |
| `env-configure-nodejs` | Configure Node.js environment |
| `env-configure-python` | Configure Python environment |
| `env-configure-maven` | Configure Maven environment |
| `env-configure-npm` | Configure npm registry |
| `env-configure-pnpm` | Configure pnpm |
| `env-configure-gradle` | Configure Gradle environment |
| `env-configure-path` | Configure PATH or environment variables |
| `env-configure-git` | Configure Git |
| `env-configure-gh` | Configure GitHub CLI |

---

## Change Log

- **v3.4** (2026-04-04): Expanded positioning from "Confluence-only" to "all reusable knowledge" - Skills can now capture knowledge from Confluence, wikis, SOPs, tribal knowledge, and best practices
- **v3.3** (2026-04-04): Consolidated documentation, added Skill Design Principles reference
- **v3.2**: Initial version with complete architecture
