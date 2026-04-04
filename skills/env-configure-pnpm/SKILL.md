---
name: env-configure-pnpm
description: >-
  Use this skill when the user wants to configure pnpm, set up .npmrc, or configure pnpm registry.
version: 1.0.0
displayName: 配置 pnpm
domain: env
action: configure
object: pnpm
tags: [env, pnpm, package, config]
type: SKILL
inputs:
  - name: registry
    type: string
    required: true
    description: npm registry 地址
  - name: npm_token
    type: string
    required: false
    description: 私有仓库 Token
---
# 配置 pnpm

## 触发条件
需要配置 pnpm 包管理器时使用。

## 前置条件
- Node.js 已配置

## 执行步骤
1. 配置 .npmrc（pnpm 使用）：
   位置：~/.npmrc（macOS / Linux）或 %USERPROFILE%\.npmrc（Windows）
   ```ini
   registry={{registry}}
   auto-install-peers=true
   strict-peer-dependencies=false
   shamefully-hoist=true
   store-dir=~/.pnpm-store
   ```

## 约束
- 只负责 pnpm 配置，不负责安装
- 幂等：已配置则检查是否正确，不重复配置
