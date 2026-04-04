---
name: env-configure-gradle
description: >-
  Use this skill when the user wants to configure Gradle, set up GRADLE_HOME, or configure Gradle environment variables.
version: 1.0.0
displayName: 配置 Gradle
domain: env
action: configure
object: gradle
tags: [env, gradle, java, build, config]
type: SKILL
inputs:
  - name: gradle_version
    type: string
    required: false
    description: Gradle 版本号（如不指定则使用已安装版本）
  - name: gradle_home
    type: string
    required: false
    description: Gradle 安装路径（如不指定则自动检测）
---
# 配置 Gradle

## 触发条件
需要配置 Gradle 构建工具时使用。

## 前置条件
- Java 已配置
- Gradle 已安装

## 执行步骤
1. 设置 GRADLE_HOME 和 PATH：
   **Windows：**
   ```powershell
   [Environment]::SetEnvironmentVariable("GRADLE_HOME", "{{gradle_home}}", "User")
   [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";%GRADLE_HOME%\bin", "User")
   $env:GRADLE_HOME = "{{gradle_home}}"
   $env:Path += ";$env:GRADLE_HOME\bin"
   ```

   **macOS / Linux (Bash)：**
   ```bash
   echo 'export GRADLE_HOME={{gradle_home}}' >> ~/.bashrc
   echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> ~/.bashrc
   export GRADLE_HOME={{gradle_home}}
   export PATH=$GRADLE_HOME/bin:$PATH
   ```

2. 配置 Gradle Init 脚本（使用内部 Nexus）：
   创建 `GRADLE_USER_HOME/init.gradle` 文件（默认 `~/.gradle/init.gradle`）：
   ```groovy
   allprojects {
       repositories {
           mavenLocal()
           maven { url 'https://nexus.company.com/repository/maven-public/' }
           maven { url 'https://nexus.company.com/repository/maven-snapshots/' }
       }
   }

   buildscript {
       repositories {
           maven { url 'https://nexus.company.com/repository/maven-public/' }
       }
   }
   ```

3. 验证安装：
   ```bash
   gradle --version
   ```

## 约束
- 只负责 Gradle 配置，不负责安装
- 需要兼容的 Java 版本
- 幂等：已配置则检查是否正确，不重复配置
