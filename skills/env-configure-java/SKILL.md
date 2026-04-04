---
name: env-configure-java
description: >-
  Use this skill when the user wants to configure Java environment variables, set up JAVA_HOME, or configure JDK environment variables.
version: 1.0.0
displayName: Configure Java Environment Variables
domain: env
action: configure
object: java
tags: [env, java, jdk, config]
type: SKILL
inputs:
  - name: java_home
    type: string
    required: false
    description: Java installation path (auto-detect if not specified)
---
# Configure Java Environment Variables

## Trigger Conditions

Use this Skill when:
- Java is installed and environment variables need to be configured
- User needs to set up JAVA_HOME for development tools
- User needs to add Java to PATH for command-line access

## Prerequisites

- Java JDK or JRE is installed on the system

## Execution Steps

### Step 1: Detect Java Installation Path

If `java_home` parameter is not provided, detect Java installation:

**Windows:**
- Check common installation directories:
  - `C:\Program Files\Java\jdk-*`
  - `C:\Program Files (x86)\Java\jdk-*`
- Use PowerShell to find installed Java versions

**macOS:**
- Use `/usr/libexec/java_home` to locate Java installation
- Check `/Library/Java/JavaVirtualMachines/` directory

**Linux:**
- Check `/usr/lib/jvm/` directory
- Use `update-alternatives --list java` if available

### Step 2: Set JAVA_HOME Environment Variable

**Windows (PowerShell):**
```powershell
# Set user-level JAVA_HOME
[Environment]::SetEnvironmentVariable("JAVA_HOME", "{{java_home}}", "User")

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentPath -notlike "*{{java_home}}\bin*") {
    $newPath = $currentPath + ";{{java_home}}\bin"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
}
```

**macOS/Linux (Shell):**
```bash
# Append to shell configuration file (~/.bashrc, ~/.zshrc, etc.)
export JAVA_HOME="{{java_home}}"
export PATH="$JAVA_HOME/bin:$PATH"
```

### Step 3: Verify Configuration

After setting environment variables:
- Check `JAVA_HOME` is correctly set
- Verify `java -version` command works
- Verify `javac -version` command works (if JDK installed)

### Step 4: Inform User

- Confirm JAVA_HOME has been configured
- Remind user to restart terminal or run `source ~/.bashrc` (macOS/Linux)
- Provide verification commands

## Constraints

- Only responsible for environment variable configuration, not Java installation
- Idempotent: check if JAVA_HOME is already correctly configured, do not rewrite if set properly
- If multiple Java versions exist, use the one specified or the system default
- User-level environment variables only (no system-wide changes)

## Error Handling

- **Java not found**: Inform user to install Java first, suggest download link
- **Invalid path**: If provided java_home doesn't exist, ask user to verify the path
- **Permission denied**: Inform user that admin privileges may be required for system variables

## Related Skills

- `env-configure-maven` - Configure Maven environment (requires Java)
- `env-configure-gradle` - Configure Gradle environment (requires Java)
