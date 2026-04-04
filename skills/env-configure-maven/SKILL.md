---
name: env-configure-maven
description: >-
  Use this skill when the user wants to configure Maven environment variables, set up MAVEN_HOME, or configure Maven settings.xml.
version: 1.0.0
displayName: Configure Maven Environment Variables and settings.xml
domain: env
action: configure
object: maven
tags: [env, maven, java, config, settings]
type: SKILL
inputs:
  - name: maven_home
    type: string
    required: false
    description: Maven installation path (auto-detect if not specified)
  - name: local_repo
    type: string
    required: false
    description: Maven local repository path (use default path if not specified)
---
# Configure Maven Environment Variables and settings.xml

## Trigger Conditions
Use when Maven is installed and environment variables and settings.xml need to be configured.

## Prerequisites
- Maven is installed
- Java is installed and environment variables are configured

## Execution Steps
1. Detect Maven installation path:
   ```bash
   mvn --version
   ```

2. Configure environment variables:

   **macOS / Linux** (write to ~/.bashrc or ~/.zshrc):
   ```bash
   export MAVEN_HOME={{maven_home}}
   export PATH=$MAVEN_HOME/bin:$PATH
   ```

   **Windows** (system environment variables):
   - MAVEN_HOME → {{maven_home}}
   - Add %MAVEN_HOME%\bin to Path

3. Configure settings.xml:

   Location: ~/.m2/settings.xml (macOS / Linux) or %USERPROFILE%\.m2\settings.xml (Windows)

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

4. Verify:
   ```bash
   mvn --version
   ```

## Constraints
- Only responsible for environment variables and settings.xml configuration
- Idempotent: check if correctly configured if already set, do not rewrite
