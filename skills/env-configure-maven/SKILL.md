---
name: env-configure-maven
description: >-
  Use this skill when the user wants to configure Maven environment variables, set up MAVEN_HOME, or configure Maven settings.xml.
version: 1.0.0
displayName: 配置 Maven 环境变量和 settings.xml
domain: env
action: configure
object: maven
tags: [env, maven, java, config, settings]
type: SKILL
inputs:
  - name: maven_home
    type: string
    required: false
    description: Maven 安装路径（如不指定则自动检测）
  - name: local_repo
    type: string
    required: false
    description: Maven 本地仓库路径（如不指定则使用默认路径）
---
# 配置 Maven 环境变量和 settings.xml

## 触发条件
Maven 已安装完成，需要配置环境变量和 settings.xml 时使用。

## 前置条件
- Maven 已安装
- Java 已安装并配置好环境变量

## 执行步骤
1. 检测 Maven 安装路径：
   ```bash
   mvn --version
   ```

2. 配置环境变量：

   **macOS / Linux**（写入 ~/.bashrc 或 ~/.zshrc）：
   ```bash
   export MAVEN_HOME={{maven_home}}
   export PATH=$MAVEN_HOME/bin:$PATH
   ```

   **Windows**（系统环境变量）：
   - MAVEN_HOME → {{maven_home}}
   - Path 添加 %MAVEN_HOME%\bin

3. 配置 settings.xml：

   位置：~/.m2/settings.xml（macOS / Linux）或 %USERPROFILE%\.m2\settings.xml（Windows）

   ```xml
   <settings>
     <localRepository>{{local_repo}}</localRepository>
     <mirrors>
       <mirror>
         <id>nexus-internal</id>
         <mirrorOf>*</mirrorOf>
         <name>Internal Nexus</name>
         <url>https://nexus.company.com/repository/maven-public/</url>
       </mirror>
     </mirrors>
     <servers>
       <server>
         <id>nexus-internal</id>
         <username>${env.NEXUS_USER}</username>
         <password>${env.NEXUS_PASS}</password>
       </server>
     </servers>
   </settings>
   ```

4. 验证：
   ```bash
   mvn --version
   ```

## 约束
- 只负责环境变量和 settings.xml 配置
- 幂等：已配置则检查是否正确，不重复写入
