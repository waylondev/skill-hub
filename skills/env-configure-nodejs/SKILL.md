---
name: env-configure-nodejs
description: >-
  该 Skill 在用户要求"配置 Node.js 环境变量"、"设置 Node 环境变量"时使用。
version: 1.0.0
displayName: 配置 Node.js 环境变量
domain: env
action: configure
object: nodejs
tags: [env, nodejs, node, npm, config]
type: SKILL
inputs:
  - name: node_install_path
    type: string
    required: false
    description: Node.js 安装路径（如不指定则自动检测）
---
# 配置 Node.js 环境变量

## 触发条件
Node.js 已安装完成，需要配置环境变量时使用。

## 前置条件
- Node.js 已安装（通过 Software Center 或其他方式）
- 如未安装，先使用 sn-request-software + swc-install-package

## 执行步骤
1. 检测 Node.js 安装路径：
   ```bash
   which node  # macOS / Linux
   where node  # Windows
   ```
   如指定了 {{node_install_path}} 则直接使用。

2. 配置环境变量：

   **macOS / Linux**（写入 ~/.bashrc 或 ~/.zshrc）：
   ```bash
   export PATH={{node_install_path}}/bin:$PATH
   ```

   **Windows**（系统环境变量）：
   - Path 添加 {{node_install_path}}

3. 验证：
   ```bash
   node --version
   npm --version
   ```

## 约束
- 只负责环境变量配置，不负责安装 Node.js
- 配置完成后需要重启终端或重新登录生效
- 幂等：已配置则检查是否正确，不重复写入
- npm 镜像配置请使用 env-configure-npm Skill
