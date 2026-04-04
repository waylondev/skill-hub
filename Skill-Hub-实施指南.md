# Skill-Hub 实施指南

> 基于 [PRD v3.2](./Skill-Hub-PRD-v3.0.md)，将产品定义转化为可执行的开发任务。
>
> **核心定位**：把 Confluence 的理论知识，变成 AI 帮你干活的能力

---

## 任务总览

```
Phase 1: 仓库基础          → 产出：Git 仓库 + 示例 Skill
Phase 2: CLI 工具          → 产出：skill 二进制（5 个命令）
Phase 3: 展示站            → 产出：静态网站
```

---

## Phase 1：仓库基础

### 任务 1.1 初始化 Git 仓库

**做什么**：创建 `skill-hub` 仓库，建立基础结构。

```bash
mkdir skill-hub && cd skill-hub
git init
mkdir -p skills/sn-request-software
mkdir -p skills/swc-install-package
mkdir -p skills/env-configure-java
```

创建 `domains.yaml`：

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
    name: 环境变量配置
    owner: platform-team
  - code: nexus
    name: Nexus 制品仓库
    owner: devops-team
  - code: vpn
    name: VPN
    owner: platform-team
  - code: hr
    name: 人力资源
    owner: hr-team
  - code: doc
    name: 文档管理
    owner: platform-team
```

创建 `registry.yaml`（空索引，CI 自动生成）和 `README.md`。

**验收**：`ls` 能看到 `skills/`、`domains.yaml`、`registry.yaml`、`README.md`。

---

### 任务 1.2 编写 3 个示例 Skill

直接复制 PRD 第 3.2 节的三个示例：

| 文件 | 来源 |
|------|------|
| `skills/sn-request-software/SKILL.md` | PRD 示例 1：ServiceNow 申请软件 |
| `skills/swc-install-package/SKILL.md` | PRD 示例 2：Software Center 安装软件 |
| `skills/env-configure-java/SKILL.md` | PRD 示例 3：配置 Java 环境变量 |

**编写要点**：
- 每个 Skill 只描述**一个系统的一个操作**，绝对不做跨系统编排
- Body 必须包含：触发条件、执行步骤、约束（含幂等性）
- 约束中明确写"只负责 XXX，不负责 YYY"，划清边界
- 前置条件中可引用其他 Skill 名称（如 `sn-request-software`），但编排逻辑由 AI 负责

**验收**：3 个 SKILL.md 存在，YAML 可解析，包含触发条件/执行步骤/约束。

---

### 任务 1.3 生成 registry.yaml

写一个脚本扫描 skills/ 下所有 SKILL.md 的 frontmatter，生成 registry.yaml。

```yaml
version: "1.0"
updated: "2026-04-04"
skills:
  - name: sn-request-software
    path: skills/sn-request-software
    version: 1.0.0
    title: ServiceNow 申请软件
    domain: sn
    tags: [servicenow, software, apply, install]
  - name: swc-install-package
    path: skills/swc-install-package
    version: 1.0.0
    title: Software Center 安装软件
    domain: swc
    tags: [software-center, install, package]
  - name: env-configure-java
    path: skills/env-configure-java
    version: 1.0.0
    title: 配置 Java 环境变量
    domain: env
    tags: [env, java, jdk, config]
```

**验收**：registry.yaml 包含所有 Skill 的索引信息。

---

## Phase 2：CLI 工具（Go + Cobra）

### 任务 2.1 项目初始化

```bash
mkdir skill-hub-cli && cd skill-hub-cli
go mod init github.com/company/skill-hub-cli
go get github.com/spf13/cobra
go get github.com/spf13/viper
go get github.com/go-git/go-git/v5
go get github.com/charmbracelet/pterm
```

**项目结构**：

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

**验收**：`go build` 成功，`./skill --help` 输出帮助信息，列出 5 个子命令。

---

### 任务 2.2 实现 SKILL.md 解析器

**文件**：`internal/parser.go`

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

解析步骤：读取文件 → 用 `---` 分隔提取 frontmatter 和 body → YAML 解析 frontmatter → body 存入 Body 字段。

**验收**：能正确解析 3 个示例 SKILL.md。

---

### 任务 2.3 实现校验器

**文件**：`internal/validator.go`

```go
func Validate(skill *Skill) []error
```

检查项：
1. `name` 非空，kebab-case，≤40 字符
2. `name` 符合 `{domain}-{action}-{object}` 三段式（确保原子粒度）
3. `description` 非空，≤2000 字符
4. `version` 非空，符合 semver
5. `domain` 非空，在 domains.yaml 中存在
6. `action` 非空，`object` 非空
7. `body` 非空，包含 `## 执行步骤`
8. `body` 包含 `## 约束`（确保边界清晰，不越权编排）

**验收**：合规返回空错误列表，不合规返回具体错误。

---

### 任务 2.4 实现 skill search

**文件**：`cmd/search.go`

逻辑：读取 registry.yaml → 关键词匹配 name/title/tags/description → `--domain` 按域过滤 → `--tag` 按标签过滤 → 表格输出。

**验收**：`skill search java` 返回 `sn-request-software`、`env-configure-java`。

---

### 任务 2.5 实现 skill install

**文件**：`cmd/install.go`

逻辑：从远程仓库拉取 Skill 目录 → 复制到 `~/.skillhub/skills/{name}/` → 已存在则提示覆盖。

**验收**：`skill install sn-request-software` → `~/.skillhub/skills/sn-request-software/SKILL.md` 存在。

---

### 任务 2.6 实现 skill uninstall

**文件**：`cmd/uninstall.go`

逻辑：删除 `~/.skillhub/skills/{name}/` → 不存在则报错。

**验收**：`skill uninstall sn-request-software` → 目录删除。

---

### 任务 2.7 实现 skill run

**文件**：`cmd/run.go`

逻辑：读取本地 SKILL.md → 解析 frontmatter → 交互式收集必填参数 → 输出完整 SKILL.md 内容供 AI Agent 消费。支持 `--param key=value` 和 `--stdin`。

**设计要点**：`skill run` 的输出是给 AI Agent 消费的，不是给人看的。AI 读取 Skill 内容后，自主决定如何执行、是否需要先调用其他 Skill、如何处理异常。

**验收**：`skill run sn-request-software` → 输出 SKILL.md 内容。

---

### 任务 2.8 实现 skill push

**文件**：`cmd/push.go`

逻辑：读取 SKILL.md → 调用 validator → 通过则创建分支、复制文件、提交 PR → 失败则报错。

**验收**：`skill push ./skills/sn-request-software` → 校验通过，PR 创建成功。

---

## Phase 3：展示站

### 任务 3.1 初始化站点

```bash
npm create astro@latest skill-hub-site
```

页面：`index.astro`（首页）、`skill/[name].astro`（详情页）。

数据源：构建时读取 skill-hub 仓库的 SKILL.md 生成页面。

**验收**：`npm run dev` 能启动。

---

### 任务 3.2 首页 + 详情页

**首页**：
- 搜索栏（支持中文关键词搜索，按域/标签过滤）
- 域分类卡片（sn、swc、env、nexus 等）
- 精选榜单（按使用频率排序的 Top Skill，新人照着装就行）
- 快速开始命令（一键复制）

**详情页**：名称/版本/作者/标签 + 功能描述 + 输入参数表 + 一句话安装命令（一键复制）。

**验收**：能看到所有 Skill，搜索可用，精选榜单按频率排序，详情页信息完整。

---

### 任务 3.3 CI/CD

push 到 main → GitHub Actions → Astro build → 部署到 GitHub Pages。

**验收**：push 代码后网站自动更新。

---

## 验收标准总览

| 阶段 | 验收条件 |
|------|---------|
| Phase 1 | Git 仓库包含 3 个合规 SKILL.md + domains.yaml + registry.yaml |
| Phase 2 | `skill search/install/uninstall/run/push` 5 个命令全部可用 |
| Phase 3 | 展示站可访问，能看到所有 Skill，搜索可用 |
