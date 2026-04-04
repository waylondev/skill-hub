---
name: env-configure-git
description: >-
  该 Skill 在用户要求"配置 Git"、"设置 Git 用户名"、"配置 Git 邮箱"时使用。
version: 1.0.0
displayName: 配置 Git
domain: env
action: configure
object: git
tags: [env, git, scm, config]
type: SKILL
inputs:
  - name: user_name
    type: string
    required: true
    description: Git 用户名
  - name: user_email
    type: string
    required: true
    description: Git 邮箱
  - name: default_branch
    type: string
    required: false
    description: 默认分支名称（默认 main）
---

## 概述

配置 Git 客户端基本设置，包括用户名、邮箱和内部 Git 服务器访问。

## 前置条件

| 项 | 说明 |
|----|------|
| 操作系统 | Windows / macOS / Linux |
| 依赖 | Git 已安装 |

## 执行步骤

### 步骤 1：配置用户名和邮箱

```bash
git config --global user.name "{{user_name}}"
git config --global user.email "{{user_email}}"
```

### 步骤 2：配置默认分支名称（可选，但推荐）

```bash
git config --global init.defaultBranch {{default_branch | default: main}}
```

### 步骤 3：配置凭证助手（Windows）

**Windows (PowerShell)：**
```powershell
git config --global credential.helper manager-core
```

**macOS：**
```bash
git config --global credential.helper osxkeychain
```

**Linux：**
```bash
git config --global credential.helper store
```

### 步骤 4：配置内部 Git 服务器（可选）

如果公司有内部 Git 服务器（如 GitLab/Gitea）：

```bash
# 配置 SSH（推荐）
ssh-keygen -t ed25519 -C "{{user_email}}"
cat ~/.ssh/id_ed25519.pub
# 复制公钥到 Git 服务器设置
```

### 步骤 5：验证配置

```bash
git config --global --list
```

## 参数说明

| 名称 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| user_name | string | 是 | - | Git 用户名 |
| user_email | string | 是 | - | Git 邮箱 |
| default_branch | string | 否 | main | 默认分支名称 |

## 约束说明

- 需要输入真实的工号和姓名
- 公司 Git 仓库推荐使用 SSH 认证
- 邮箱必须是公司邮箱

## 错误处理

| 错误码 | 含义 | 处理方式 |
|--------|------|----------|
| 1 | Git 未安装 | 先在 ServiceNow 申请 Git 安装 |
| 2 | 参数缺失 | 提供 user_name 和 user_email |

## 相关 Skill

- `env-configure-gh` - 配置 GitHub CLI
