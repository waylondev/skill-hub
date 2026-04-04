---
name: env-configure-gradle
description: >-
  Use this skill when the user wants to configure Gradle build tool environment and repository settings.
version: 1.0.0
displayName: Configure Gradle
domain: env
action: configure
object: gradle
tags: [env, gradle, java, build, config]
type: SKILL
inputs:
  - name: gradle_home
    type: string
    required: false
    description: Gradle installation path (auto-detect if not specified)
  - name: repository_url
    type: string
    required: false
    description: Custom Maven repository URL for dependency resolution (optional, uses Gradle defaults if not specified)
  - name: gradle_user_home
    type: string
    required: false
    description: Custom Gradle user home directory (optional, uses ~/.gradle if not specified)
---
# Configure Gradle

## Purpose

Configure Gradle build tool with environment variables and repository settings for building Java/Kotlin projects.

## Trigger Conditions

Use this Skill when:
- Gradle is installed and needs environment configuration
- User needs to set up GRADLE_HOME environment variable
- User wants to configure custom Maven repositories for dependency resolution
- Setting up Gradle for enterprise development with internal artifact repositories

## Prerequisites

- Java is installed and JAVA_HOME is configured
- Gradle is installed on the system

## Execution Steps

### Step 1: Detect Gradle Installation

If `gradle_home` parameter is not provided:
- Locate Gradle installation using system-specific methods
- Check common installation directories
- Verify Gradle is accessible from command line
- If Gradle is not found, inform user

### Step 2: Set GRADLE_HOME Environment Variable

Configure the GRADLE_HOME environment variable:
- Point to the Gradle installation directory
- Use user-level environment variable (not system-level)
- Check if already correctly configured (idempotent)

### Step 3: Add Gradle to PATH

Ensure Gradle executables are accessible:
- Add GRADLE_HOME/bin to PATH
- Avoid duplicate entries
- Use appropriate path separator for the platform

### Step 4: Configure Gradle User Home (Optional)

If `gradle_user_home` is provided:
- Set GRADLE_USER_HOME environment variable
- This controls where Gradle stores caches and init scripts
- If not provided, use default (~/.gradle)

### Step 5: Configure Repository Settings

If `repository_url` is provided:
- Create or update Gradle init script
- Configure custom Maven repositories for dependency resolution
- Set up both allprojects and buildscript repositories
- If multiple repositories needed, configure in priority order

**Init script location:**
- Use GRADLE_USER_HOME/init.gradle or GRADLE_USER_HOME/init.d/ directory
- Supports multiple repository configuration files

**Repository configuration guidance:**
- Configure internal Nexus/Artifactory repositories
- Set up proper authentication if required
- Ensure repositories are accessible from user's network

### Step 6: Verify Configuration

After configuration:
- Verify Gradle is accessible: run Gradle version command
- Confirm GRADLE_HOME is correctly set
- Test Gradle can resolve dependencies from configured repositories
- Optionally, run a simple Gradle build to verify

### Step 7: Inform User

- Confirm Gradle has been configured successfully
- Provide summary of configured settings
- Remind user that terminal restart may be required
- Explain how to verify repository configuration in build files

## Constraints

- Only responsible for Gradle environment and repository configuration, not installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Do not hardcode specific repository URLs - use provided parameter or inform user to specify
- Repository authentication should use Gradle's secure credential management
- Init scripts should not override project-specific repository settings

## Error Handling

- **Gradle not found**: Inform user to install Gradle first or provide the installation path
- **JAVA_HOME not set**: Inform user that Java must be configured first, suggest using `env-configure-java`
- **Repository unreachable**: If provided repository URL is not accessible, inform user to verify network access
- **Init script write error**: Inform user about file permissions issue

## Related Skills

- `env-configure-java` - Configure Java environment (prerequisite for Gradle)
- `env-configure-maven` - Configure Maven (alternative build tool)
- `env-configure-path` - Generic path configuration alternative
