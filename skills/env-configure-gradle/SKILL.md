---
name: env-configure-gradle
description: >-
  该 Skill 在用户要求"配置 Gradle"、"配置 GRADLE_HOME"、"设置 Gradle 环境变量"时使用。
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
    description: Gradle 版本号（默认 8.5）
  - name: gradle_home
    type: string
    required: false
    description: Gradle 安装路径（默认自动检测）
---

## 概述

配置 Gradle 构建工具环境变量和 init 脚本，连接内部 Nexus 仓库。

## 前置条件

| 项 | 说明 |
|----|------|
| 操作系统 | Windows / macOS / Linux |
| 依赖 | Java 11+ (已配置 JAVA_HOME) |

## 执行步骤

### 步骤 1：设置 GRADLE_HOME 和 PATH

**Windows：**
```powershell
# 设置环境变量
[Environment]::SetEnvironmentVariable("GRADLE_HOME", "{{gradle_home | default: C:\Program Files\Gradle\gradle-8.5}}", "User")
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";%GRADLE_HOME%\bin", "User")

# 刷新当前会话
$env:GRADLE_HOME = "{{gradle_home | default: C:\Program Files\Gradle\gradle-8.5}}"
$env:Path += ";$env:GRADLE_HOME\bin"
```

**macOS / Linux (Bash)：**
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
echo 'export GRADLE_HOME={{gradle_home | default: /opt/gradle/gradle-8.5}}' >> ~/.bashrc
echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> ~/.bashrc

# 刷新当前会话
export GRADLE_HOME={{gradle_home | default: /opt/gradle/gradle-8.5}}
export PATH=$GRADLE_HOME/bin:$PATH
source ~/.bashrc
```

### 步骤 2：配置 Gradle Init 脚本（使用内部 Nexus）

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

### 步骤 3：验证安装

```bash
gradle --version
```

## 参数说明

| 名称 | 类型 | 必填 | 默认 | 说明 |
|------|------|------|------|------|
| gradle_version | string | 否 | 8.5 | Gradle 版本号 |
| gradle_home | string | 否 | 自动检测 | Gradle 安装路径 |

## 约束说明

- 需要 Java 11 或更高版本
- 需要配置 GRADLE_USER_HOME（默认 ~/.gradle）
- init.gradle 需要放在正确位置

## 错误处理

| 错误码 | 含义 | 处理方式 |
|--------|------|----------|
| 1 | Java 未安装 | 先运行 env-configure-java |
| 2 | Gradle 未安装 | 先在 ServiceNow 申请 Gradle |

## 相关 Skill

- `env-configure-java` - 配置 Java
- `env-configure-maven` - 配置 Maven
