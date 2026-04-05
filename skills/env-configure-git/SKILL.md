---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git username and email,
  set up Git identity for commits, or verify Git configuration.
  Supports idempotent configuration (checks before applying).
version: 1.0.0
displayName: Configure Git Identity
domain: env
action: configure
object: git
tags: [env, git, scm, config]
type: SKILL
inputs:
  - name: user_name
    type: string
    required: true
    description: Git username for commits
  - name: user_email
    type: string
    required: true
    description: Git email for commits
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

- **Git not installed**: Inform user Git is not installed
- **Invalid email format**: Inform user provided email format appears invalid
- **Already configured**: Inform user Git username and email are already configured correctly
- **Configuration file locked**: Inform user cannot write to git config file, check permissions
