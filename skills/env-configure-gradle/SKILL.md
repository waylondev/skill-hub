---
name: env-configure-gradle
description: >-
  Use this skill when the user wants to configure Gradle, set up GRADLE_HOME, or configure Gradle environment variables.
version: 1.0.0
displayName: Configure Gradle
domain: env
action: configure
object: gradle
tags: [env, gradle, java, build, config]
type: SKILL
inputs:
  - name: gradle_version
    type: string
    required: false
    description: Gradle version (use installed version if not specified)
  - name: gradle_home
    type: string
    required: false
    description: Gradle installation path (auto-detect if not specified)
---
# Configure Gradle

## Trigger Conditions
Use when configuring Gradle build tool.

## Prerequisites
- Java is configured
- Gradle is installed

## Execution Steps
1. Set GRADLE_HOME and PATH:
   **Windows:**
   ```powershell
   [Environment]::SetEnvironmentVariable("GRADLE_HOME", "{{gradle_home}}", "User")
   [Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";%GRADLE_HOME%\bin", "User")
   $env:GRADLE_HOME = "{{gradle_home}}"
   $env:Path += ";$env:GRADLE_HOME\bin"
   ```

   **macOS / Linux (Bash):**
   ```bash
   echo 'export GRADLE_HOME={{gradle_home}}' >> ~/.bashrc
   echo 'export PATH=$GRADLE_HOME/bin:$PATH' >> ~/.bashrc
   export GRADLE_HOME={{gradle_home}}
   export PATH=$GRADLE_HOME/bin:$PATH
   ```

2. Configure Gradle Init script (using internal Nexus):
   Create `GRADLE_USER_HOME/init.gradle` file (default `~/.gradle/init.gradle`):
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

3. Verify installation:
   ```bash
   gradle --version
   ```

## Constraints
- Only responsible for Gradle configuration, not installation
- Requires compatible Java version
- Idempotent: check if correctly configured if already set, do not reconfigure
