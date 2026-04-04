---
name: env-configure-java
description: >-
  Use this skill when the user wants to configure Java environment variables, set up JAVA_HOME, or configure JDK environment variables.
version: 1.0.0
displayName: 配置 Java 环境变量
domain: env
action: configure
object: java
tags: [env, java, jdk, config]
type: SKILL
inputs:
  - name: java_home
    type: string
    required: false
    description: Java 安装路径（如不指定则自动检测）
---
# 配置 Java 环境变量

## 触发条件
Java 已安装完成，需要配置环境变量时使用。

## 前置条件
- Java 已安装

## 执行步骤
1. 检测 Java 安装路径：
   ```bash
   /usr/libexec/java_home -V 2>/dev/null   # macOS
   ls /usr/lib/jvm/                           # Linux
   ```

2. 配置环境变量：

   **macOS / Linux**（写入 ~/.bashrc 或 ~/.zshrc）：
   ```bash
   export JAVA_HOME={{java_home}}
   export PATH=$JAVA_HOME/bin:$PATH
   ```

   **Windows**（系统环境变量）：
   - JAVA_HOME → {{java_home}}
   - Path 添加 %JAVA_HOME%\bin

3. 验证：
   ```bash
   java -version
   echo $JAVA_HOME
   ```

## 约束
- 只负责环境变量配置，不负责安装 Java
- 幂等：已配置则检查是否正确，不重复写入
