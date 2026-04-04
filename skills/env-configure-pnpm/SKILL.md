---
name: env-configure-pnpm
description: >-
  该 Skill 在用户要求"配置 pnpm"、"设置 .npmrc"、"配置 pnpm 镜像"时使用。
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

## 概述

配置 pnpm 包管理器，包括 .npmrc、pnpm-workspace.yaml 等。

## 前置条件

| 项 | 说明 |
|----|------|
| 操作系统 | Windows / macOS / Linux |
| 依赖 | Node.js 已配置 |

## 执行步骤

### 步骤 1：配置 .npmrc（pnpm 使用）

```ini
# .npmrc
registry={{registry}}
auto-install-peers=true
strict-peer-dependencies=false
shamefully-hoist=true
store-dir=~/.pnpm-store
```

### 步骤 2：配置 pnpm-workspace.yaml（Monorepo）

```yaml
# pnpm-workspace.yaml
packages:
  - 'packages/*'
  - 'apps/*'
```

### 步骤 3：配置 .pnpmfile.cjs

```javascript
// .pnpmfile.cjs
function readPackage(pkg, context) {
  if (pkg.dependencies && pkg.dependencies['some-package']) {
    pkg.dependencies['some-package'] = '^1.2.3';
  }
  return pkg;
}

module.exports = {
  hooks: {
    readPackage,
  },
};
```

### 步骤 4：配置 package.json 脚本

```json
{
  "packageManager": "pnpm@8.15.0",
  "scripts": {
    "dev": "pnpm -F app dev",
    "build": "pnpm -r build",
    "test": "pnpm -r test",
    "lint": "pnpm -r lint"
  }
}
```

### 步骤 5：配置环境变量（.npmrc.private，可选，不提交 Git）

```ini
# .npmrc.private
//nexus.company.com/repository/npm-private/:_authToken=${NPM_TOKEN}
```

## 参数说明

| 名称 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| registry | string | 是 | - | npm registry 地址 |
| npm_token | string | 否 | - | 私有仓库 Token |

## 约束说明

- .npmrc.private 不应提交到 Git
- packageManager 字段指定 pnpm 版本
- Monorepo 项目需要 pnpm-workspace.yaml

## 错误处理

| 错误码 | 含义 | 处理方式 |
|--------|------|----------|
| 1 | Node.js 未配置 | 先运行 env-configure-nodejs |

## 相关 Skill

- `env-configure-nodejs` - 配置 Node.js
- `env-configure-npm` - 配置 npm
