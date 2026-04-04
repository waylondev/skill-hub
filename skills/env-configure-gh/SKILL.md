---
name: env-configure-gh
description: >-
  Use this skill when the user wants to configure GitHub CLI, set up gh, or configure GitHub command-line tool.
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
# 配置 GitHub CLI

## 触发条件
需要配置 GitHub CLI (gh) 用于命令行操作 GitHub 时使用。

## 前置条件
- Git 已配置
- GitHub CLI 已安装

## 执行步骤
1. 确认安装状态：
   ```bash
   gh --version
   ```

2. 认证登录：
   ```bash
   gh auth login
   ```

3. 验证认证状态：
   ```bash
   gh auth status
   ```

## 约束
- 只负责 GitHub CLI 配置，不负责安装
- 需要 GitHub 账号
- 企业版需要使用正确的 GitHub Enterprise URL
- 幂等：已配置则检查是否正确，不重复配置
