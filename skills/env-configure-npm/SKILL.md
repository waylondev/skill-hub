---
name: env-configure-npm
description: >-
  Use this skill when the user wants to configure npm mirror, set up .npmrc, or configure internal Nexus npm registry.
version: 1.0.0
displayName: 配置 npm 内部 Nexus 镜像
domain: env
action: configure
object: npm
tags: [env, npm, nodejs, config, registry]
type: SKILL
inputs:
  - name: npm_registry_url
    type: string
    required: false
    description: Nexus npm 仓库地址（默认 https://nexus.company.com/repository/npm-public/）
---
# 配置 npm 内部 Nexus 镜像

## 触发条件
需要配置 npm 使用内部 Nexus 镜像源时使用。

## 前置条件
- Node.js 和 npm 已安装

## 执行步骤
1. 配置 npm registry：
   ```bash
   npm config set registry {{npm_registry_url}}
   npm config set always-auth true
   ```

2. 验证：
   ```bash
   npm config get registry
   npm config list
   ```

## 约束
- 需要从 IT 获取 NEXUS_TOKEN 或 NPM_TOKEN
- 幂等：已配置则检查是否正确，不重复写入
