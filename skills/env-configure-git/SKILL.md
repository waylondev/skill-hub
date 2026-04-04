---
name: env-configure-git
description: >-
  Configure Git username and email for commits.
  Invoke when user needs to set up Git identity or verify Git configuration.
  Supports idempotent configuration (checks before applying).
version: 1.0.0
displayName: Configure Git
domain: env
action: configure
object: git
tags: [env, git, scm, config]
type: SKILL
inputs:
  - name: user_name
    type: string
    required: true
    description: Git username to display in commits
  - name: user_email
    type: string
    required: true
    description: Git email address for commits
---
# Configure Git

## Purpose

Configure Git global username and email for commits only. Does not handle credential helper or other advanced Git configurations.

## Trigger Conditions

Use this Skill when:
- Git is installed and needs initial configuration
- User needs to set up Git username and email for commits
- User wants to verify Git configuration

## Prerequisites

- Git is installed on the system

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- Check if Git is installed
- If not installed, inform user and stop

### Step 2: Check Current Configuration (Idempotency)

Before making changes:
- Check current Git username and email
- If both are already set to the provided values, inform user no changes needed and stop

### Step 3: Configure Git Identity

Set the global Git username and email:
- Apply configuration at global level (user's home directory)
- Set username and email to the provided parameters

### Step 4: Verify Configuration

After configuration:
- Verify username is correctly set
- Verify email is correctly set
- Display current Git configuration summary

### Step 5: Inform User

- Confirm Git has been configured successfully
- Provide summary of configured settings
- Remind user that these settings apply globally to all repositories

## Constraints

- **Single Responsibility**: Only configures Git username and email, not other Git settings
- **Idempotent**: Check first, configure only if different
- **Prerequisite Check**: If Git is not installed, inform user and stop
- Configuration is at global level, not repository-specific

## Error Handling

- **Git not installed**: "Git is not installed. Please install Git first."
- **Invalid email format**: "The provided email format appears invalid. Please verify the email address."
- **Already configured**: "Git username and email are already configured correctly. No action needed."
- **Configuration file locked**: "Cannot write to .gitconfig file. Please check file permissions."

## Related Skills

- `env-configure-path` - Configure PATH if Git commands are not accessible
- `env-configure-gh` - Configure GitHub CLI (requires Git to be configured first)
