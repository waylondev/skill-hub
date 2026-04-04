---
name: env-configure-python
description: >-
  Use this skill when the user wants to configure Python environment variables or set up Python environment variables.
version: 1.0.0
displayName: 配置 Python 环境变量
domain: env
action: configure
object: python
tags: [env, python, config]
type: SKILL
inputs:
  - name: python_install_path
    type: string
    required: false
    description: Python 安装路径（如不指定则自动检测）
---
# 配置 Python 环境变量

## 触发条件
Python 已安装完成，需要配置环境变量时使用。

## 前置条件
- Python 已安装

## 执行步骤
1. 检测 Python 安装路径：
   ```bash
   which python3  # macOS / Linux
   where python   # Windows
   ```

2. 配置环境变量：

   **macOS / Linux**（写入 ~/.bashrc 或 ~/.zshrc）：
   ```bash
   export PATH={{python_install_path}}:$PATH
   export PATH={{python_install_path}}/Scripts:$PATH
   alias python=python3
   alias pip=pip3
   ```

   **Windows**（系统环境变量）：
   - Path 添加 {{python_install_path}}
   - Path 添加 {{python_install_path}}\Scripts

3. 验证：
   ```bash
   python --version
   pip --version
   ```

## 约束
- 只负责环境变量配置，不负责安装 Python
- 配置完成后需要重启终端生效
- 幂等：已配置则检查是否正确，不重复写入
