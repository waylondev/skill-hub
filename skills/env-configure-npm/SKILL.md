---
name: env-configure-npm
description: >-
  该 Skill 在用户要求"配置 npm 镜像"、"配置 .npmrc"、"设置内部 Nexus npm 源"时使用。
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
- 如未安装，先使用 sn-request-software（software_name=Node.js）+ swc-install-package

## 执行步骤
1. 确认 npm registry 地址：{{npm_registry_url}}（默认 https://nexus.company.com/repository/npm-public/）

2. 配置 .npmrc：

   位置：~/.npmrc（macOS / Linux）或 %USERPROFILE%\.npmrc（Windows）

   ```ini
   registry={{npm_registry_url}}
   //nexus.company.com/repository/npm-public/:_authToken=${NPM_TOKEN}
   always-auth=true
   ```

3. 或者使用 npm config 命令：
   ```bash
   npm config set registry {{npm_registry_url}}
   npm config set always-auth true
   ```

4. 验证：
   ```bash
   npm config get registry
   npm config list
   ```

5. 测试安装（可选）：
   ```bash
   npm install -g lodash --registry={{npm_registry_url}}
   ```

## 约束
- 需要从 IT 获取 NEXUS_TOKEN 或 NPM_TOKEN
- 可以同时配置 env-configure-maven（Maven 镜像）
- 幂等：已配置则检查是否正确，不重复写入
