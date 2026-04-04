---
name: env-configure-gh
description: >-
  该 Skill 在用户要求"配置 GitHub CLI"、"安装 gh"、"配置 GitHub 命令行工具"时使用。
version: 1.0.0
displayName: 配置 GitHub CLI
domain: env
action: configure
object: gh
tags: [env, github, cli, gh, scm]
type: SKILL
inputs:
  - name: github_host
    type: string
    required: false
    description: GitHub 服务器地址（企业版使用，默认 github.com）
  - name: auth_method
    type: string
    required: false
    description: 认证方式：browser 或 token
---

## 概述

安装和配置 GitHub CLI (gh)，用于命令行操作 GitHub。

## 前置条件

| 项 | 说明 |
|----|------|
| 操作系统 | Windows / macOS / Linux |
| 依赖 | Git 已配置 |

## 执行步骤

### 步骤 1：安装 GitHub CLI

**Windows (使用 Chocolatey/Scoop)：**
```powershell
# Chocolatey
choco install gh

# 或 Scoop
scoop install gh
```

**macOS：**
```bash
brew install gh
```

**Linux (Ubuntu/Debian)：**
```bash
sudo apt install gh
```

### 步骤 2：认证登录

```bash
gh auth login
```

按照提示选择：
- 账户：GitHub.com 或 GitHub Enterprise
- 协议：HTTPS 或 SSH
- 认证方式：浏览器登录或 Personal Access Token

### 步骤 3：验证安装

```bash
gh --version
gh auth status
```

### 步骤 4：常用操作示例

```bash
# 克隆仓库
gh repo clone owner/repo

# 创建 PR
gh pr create --title "My PR" --body "Description"

# 查看 Issues
gh issue list
```

## 参数说明

| 名称 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| github_host | string | 否 | github.com | GitHub 服务器地址（企业版使用） |
| auth_method | string | 否 | browser | 认证方式：browser 或 token |

## 约束说明

- 需要 GitHub 账号
- 企业版需要使用正确的 GitHub Enterprise URL
- 建议使用 SSH 认证（需要先配置 SSH 密钥）

## 错误处理

| 错误码 | 含义 | 处理方式 |
|--------|------|----------|
| 1 | gh 未安装 | 先用包管理器安装 gh |
| 2 | 认证失败 | 重新运行 gh auth login |

## 相关 Skill

- `env-configure-git` - 配置 Git
