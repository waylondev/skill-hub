---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git, set up Git username, or configure Git email.
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
# 配置 Git

## 触发条件
Git 已安装完成，需要配置用户名、邮箱等基本设置时使用。

## 前置条件
- Git 已安装

## 执行步骤
1. 配置用户名和邮箱：
   ```bash
   git config --global user.name "{{user_name}}"
   git config --global user.email "{{user_email}}"
   ```

2. 配置默认分支名称（可选）：
   ```bash
   git config --global init.defaultBranch {{default_branch | default: main}}
   ```

3. 配置凭证助手：
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

4. 验证配置：
   ```bash
   git config --global --list
   ```

## 约束
- 只负责 Git 配置，不负责安装 Git
- 邮箱必须是公司邮箱
- 幂等：已配置则检查是否正确，不重复配置
