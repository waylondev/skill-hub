# Skill-Hub Implementation Guide

> Based on [PRD v3.2](./Skill-Hub-PRD-v3.0.md), transforming product definitions into executable development tasks.
>
> **Core Positioning**: Turn Confluence theoretical knowledge into AI execution capabilities

---

## Task Overview

```
Phase 1: Repository Foundation → Output: Git Repository + Example Skills
Phase 2: CLI Tool              → Output: skill binary (5 commands)
Phase 3: Showcase Site         → Output: Static Website
```

---

## Phase 1: Repository Foundation

### Task 1.1 Initialize Git Repository

**What to do**: Create `skill-hub` repository, establish basic structure.

```bash
mkdir skill-hub && cd skill-hub
git init
mkdir -p skills/sn-request-software
mkdir -p skills/swc-install-package
mkdir -p skills/env-configure-java
```

Create `domains.yaml`:

```yaml
version: "1.0"
maintainer: platform-team
domains:
  - code: sn
    name: ServiceNow
    owner: platform-team
  - code: swc
    name: Software Center
    owner: platform-team
  - code: env
    name: Environment Configuration
    owner: platform-team
  - code: nexus
    name: Nexus Artifact Repository
    owner: devops-team
  - code: vpn
    name: VPN
    owner: platform-team
  - code: hr
    name: Human Resources
    owner: hr-team
  - code: doc
    name: Document Management
    owner: platform-team
```

Create `registry.yaml` (empty index, CI auto-generates) and `README.md`.

**Acceptance**: `ls` shows `skills/`, `domains.yaml`, `registry.yaml`, `README.md`.

---

### Task 1.2 Write 3 Example Skills

Directly copy the three examples from PRD Section 3.2:

| File | Source |
|------|--------|
| `skills/sn-request-software/SKILL.md` | PRD Example 1: ServiceNow Request Software |
| `skills/swc-install-package/SKILL.md` | PRD Example 2: Software Center Install Software |
| `skills/env-configure-java/SKILL.md` | PRD Example 3: Configure Java Environment Variables |

**Writing Points**:
- Each Skill only describes **one operation in one system**, absolutely no cross-system orchestration
- Body must contain: Trigger Conditions, Execution Steps, Constraints (including idempotency)
- Constraints clearly state "only responsible for XXX, not responsible for YYY", defining boundaries
- Prerequisites can reference other Skill names (like `sn-request-software`), but orchestration logic is AI's responsibility

**Acceptance**: 3 SKILL.md files exist, YAML parsable, contain trigger conditions/execution steps/constraints.

---

### Task 1.3 Generate registry.yaml

Write a script to scan all SKILL.md files under skills/, parse frontmatter, generate registry.yaml.

```yaml
version: "1.0"
updated: "2026-04-04"
skills:
  - name: sn-request-software
    path: skills/sn-request-software
    version: 1.0.0
    title: ServiceNow Request Software
    domain: sn
    tags: [servicenow, software, apply, install]
  - name: swc-install-package
    path: skills/swc-install-package
    version: 1.0.0
    title: Software Center Install Software
    domain: swc
    tags: [software-center, install, package]
  - name: env-configure-java
    path: skills/env-configure-java
    version: 1.0.0
    title: Configure Java Environment Variables
    domain: env
    tags: [env, java, jdk, config]
```

**Acceptance**: registry.yaml contains index information for all Skills.

---

## Phase 2: CLI Tool (Go + Cobra)

### Task 2.1 Project Initialization

```bash
mkdir skill-hub-cli && cd skill-hub-cli
go mod init github.com/company/skill-hub-cli
go get github.com/spf13/cobra
go get github.com/spf13/viper
go get github.com/go-git/go-git/v5
go get github.com/charmbracelet/pterm
```

**Project Structure**:

```
skill-hub-cli/
├── cmd/
│   ├── root.go
│   ├── search.go
│   ├── install.go
│   ├── uninstall.go
│   ├── run.go
│   └── push.go
├── internal/
│   ├── parser.go
│   ├── validator.go
│   └── registry.go
├── .goreleaser.yaml
├── go.mod
└── Makefile
```

**Acceptance**: `go build` succeeds, `./skill --help` outputs help information, lists 5 subcommands.

---

### Task 2.2 Implement SKILL.md Parser

**File**: `internal/parser.go`

```go
type Skill struct {
    Name        string     `yaml:"name"`
    Description string     `yaml:"description"`
    Version     string     `yaml:"version"`
    DisplayName string     `yaml:"displayName"`
    Author      string     `yaml:"author"`
    Team        string     `yaml:"team"`
    Domain      string     `yaml:"domain"`
    Action      string     `yaml:"action"`
    Object      string     `yaml:"object"`
    Tags        []string   `yaml:"tags"`
    Inputs      []InputDef `yaml:"inputs"`
    Body        string     `yaml:"-"`
}

type InputDef struct {
    Name        string   `yaml:"name"`
    Type        string   `yaml:"type"`
    Required    bool     `yaml:"required"`
    Description string   `yaml:"description"`
    Default     string   `yaml:"default"`
    Enum        []string `yaml:"enum"`
}

func ParseSkillFile(path string) (*Skill, error)
```

Parsing steps: Read file → Extract frontmatter and body using `---` separator → Parse frontmatter with YAML → Store body in Body field.

**Acceptance**: Can correctly parse 3 example SKILL.md files.

---

### Task 2.3 Implement Validator

**File**: `internal/validator.go`

```go
func Validate(skill *Skill) []error
```

Validation items:
1. `name` not empty, kebab-case, ≤40 characters
2. `name` follows `{domain}-{action}-{object}` three-part format (ensures atomic granularity)
3. `description` not empty, ≤2000 characters
4. `version` not empty, follows semver
5. `domain` not empty, exists in domains.yaml
6. `action` not empty, `object` not empty
7. `body` not empty, contains `## Execution Steps`
8. `body` contains `## Constraints` (ensures clear boundaries, no overstepping orchestration)

**Acceptance**: Compliant returns empty error list, non-compliant returns specific errors.

---

### Task 2.4 Implement skill search

**File**: `cmd/search.go`

Logic: Read registry.yaml → Keyword matching on name/title/tags/description → `--domain` filter by domain → `--tag` filter by tag → Table output.

**Acceptance**: `skill search java` returns `sn-request-software`, `env-configure-java`.

---

### Task 2.5 Implement skill install

**File**: `cmd/install.go`

Logic: Pull Skill directory from remote repository → Copy to `~/.skillhub/skills/{name}/` → If exists, prompt for overwrite.

**Acceptance**: `skill install sn-request-software` → `~/.skillhub/skills/sn-request-software/SKILL.md` exists.

---

### Task 2.6 Implement skill uninstall

**File**: `cmd/uninstall.go`

Logic: Delete `~/.skillhub/skills/{name}/` → If doesn't exist, report error.

**Acceptance**: `skill uninstall sn-request-software` → Directory deleted.

---

### Task 2.7 Implement skill run

**File**: `cmd/run.go`

Logic: Read local SKILL.md → Parse frontmatter → Interactively collect required parameters → Output complete SKILL.md content for AI Agent consumption. Supports `--param key=value` and `--stdin`.

**Design Point**: `skill run` output is for AI Agent consumption, not for human viewing. After AI reads Skill content, it autonomously decides how to execute, whether to call other Skills first, and how to handle exceptions.

**Acceptance**: `skill run sn-request-software` → Outputs SKILL.md content.

---

### Task 2.8 Implement skill push

**File**: `cmd/push.go`

Logic: Read SKILL.md → Call validator → If passes, create branch, copy files, submit PR → If fails, report error.

**Acceptance**: `skill push ./skills/sn-request-software` → Validation passes, PR created successfully.

---

## Phase 3: Showcase Site

### Task 3.1 Initialize Site

```bash
npm create astro@latest skill-hub-site
```

Pages: `index.astro` (homepage), `skill/[name].astro` (detail page).

Data source: Read SKILL.md files from skill-hub repository during build to generate pages.

**Acceptance**: `npm run dev` can start.

---

### Task 3.2 Homepage + Detail Page

**Homepage**:
- Search bar (supports Chinese keyword search, filter by domain/tag)
- Domain category cards (sn, swc, env, nexus, etc.)
- Featured list (Top Skills sorted by usage frequency, new hires can follow)
- Quick start commands (one-click copy)

**Detail Page**: Name/version/author/tags + function description + input parameter table + one-sentence install command (one-click copy).

**Acceptance**: Can see all Skills, search works, featured list sorted by frequency, detail page information complete.

---

### Task 3.3 CI/CD

push to main → GitHub Actions → Astro build → Deploy to GitHub Pages.

**Acceptance**: Website automatically updates after pushing code.

---

## Acceptance Criteria Overview

| Phase | Acceptance Conditions |
|-------|----------------------|
| Phase 1 | Git repository contains 3 compliant SKILL.md + domains.yaml + registry.yaml |
| Phase 2 | `skill search/install/uninstall/run/push` 5 commands all usable |
| Phase 3 | Showcase site accessible, can see all Skills, search works |