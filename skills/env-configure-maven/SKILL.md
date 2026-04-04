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
  - name: nexus_url
    type: string
    required: false
    description: Internal Nexus repository URL (optional, use company default if not specified)
---
# Configure Maven Environment Variables and settings.xml

## Trigger Conditions

Use this Skill when:
- Maven is installed and needs environment configuration
- User needs to set up MAVEN_HOME environment variable
- User needs to configure Maven settings.xml with internal repository
- User wants to use company's internal Nexus repository

## Prerequisites

- Maven is installed on the system
- Java is installed and environment variables are configured (JAVA_HOME should be set)

## Execution Steps

### Step 1: Detect Maven Installation

If `maven_home` parameter is not provided:
- Use Maven command to detect installation location
- Verify Maven is accessible from command line
- If Maven is not found, inform user

### Step 2: Set MAVEN_HOME Environment Variable

Configure the MAVEN_HOME environment variable:
- Point to the Maven installation directory
- Use user-level environment variable (not system-level)
- Check if already correctly configured (idempotent)

### Step 3: Add Maven to PATH

Ensure Maven's bin directory is in the system PATH:
- Add MAVEN_HOME/bin to PATH
- Avoid duplicate entries
- Use appropriate path separator for the platform

### Step 4: Configure settings.xml

Create or update Maven settings.xml file:

**Location:**
- macOS/Linux: `~/.m2/settings.xml`
- Windows: `%USERPROFILE%\.m2\settings.xml`

**Configuration elements:**

1. **Local Repository** (if `local_repo` is provided):
   - Set custom local repository path
   - If not provided, use Maven default (~/.m2/repository)

2. **Mirror Configuration** (if `nexus_url` is provided):
   - Configure internal Nexus repository as mirror
   - Set mirrorOf to "*" to use for all artifacts
   - Use company's Nexus URL

3. **Server Credentials** (if Nexus is configured):
   - Reference environment variables for credentials (NEXUS_USER, NEXUS_PASS)
   - Do not hardcode credentials in settings.xml

### Step 5: Verify Configuration

After configuration:
- Verify Maven is accessible: run Maven version command
- Confirm MAVEN_HOME is correctly set
- Confirm settings.xml is valid XML and properly configured

### Step 6: Inform User

- Confirm Maven has been configured successfully
- Provide summary of configured settings
- Remind user that terminal restart may be required
- Explain how to verify the configuration

## Constraints

- Only responsible for environment variables and settings.xml configuration, not Maven installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Do not hardcode credentials - always use environment variable references
- Use company's default Nexus URL if not specified
- Local repository path should use platform-appropriate path format

## Error Handling

- **Maven not found**: Inform user to install Maven first or provide the installation path
- **JAVA_HOME not set**: Inform user that Java must be configured first, suggest using `env-configure-java`
- **settings.xml write error**: Inform user about file permissions issue
- **Invalid Nexus URL**: If provided URL is invalid format, warn user but still configure

## Related Skills

- `env-configure-java` - Configure Java environment (prerequisite for Maven)
- `env-configure-path` - Generic path configuration alternative
