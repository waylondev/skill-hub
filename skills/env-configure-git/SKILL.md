---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git with username and email for commits.
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
- **Check if Git is installed**: Run `git --version`. If not found, inform user: "Git is not installed. Please install Git first." Stop and do not proceed.
- If prerequisites are not met, inform user and stop.

### Step 2: Check Current Configuration (Idempotency)

Before making changes:
- Get current Git username: `git config --global user.name`
- Get current Git email: `git config --global user.email`
- If both are already set to the provided values, inform user: "Git username and email are already configured correctly. No changes needed." and stop.

### Step 3: Configure Git Username

Set the global username that will appear in commits:
- Use the `user.name` configuration key
- Apply at global level (~/.gitconfig)
- Set to the provided `user_name` parameter

### Step 4: Configure Git Email

Set the email address that will be associated with commits:
- Use the `user.email` configuration key
- Apply at global level
- Ensure the email format is valid
- Set to the provided `user_email` parameter

### Step 5: Verify Configuration

After configuration:
- Verify username is correctly set: `git config --global user.name`
- Verify email is correctly set: `git config --global user.email`
- Display current Git configuration summary

### Step 6: Inform User

- Confirm Git has been configured successfully
- Provide summary of configured settings (username and email)
- Remind user that these settings apply globally to all repositories
- If needed, explain how to override settings for specific repositories

## Constraints

- **Single Responsibility**: Only configures Git username and email. Does not configure credential helper, default branch, or other Git settings.
- **Idempotent**: Check first, configure only if different. If already set correctly, do nothing.
- **Prerequisite Check**: If Git is not installed, inform user and stop.
- Configuration is at global level (~/.gitconfig), not repository-specific
- Email should be the user's preferred email for commits

## Error Handling

- **Git not installed**: "Git is not installed. Please install Git first."
- **Invalid email format**: "The provided email format appears invalid. Please verify the email address."
- **Already configured**: "Git username and email are already configured correctly. No action needed."
- **Configuration file locked**: "Cannot write to .gitconfig file. Please check file permissions."

## Related Skills

- `env-configure-path` - Configure PATH if Git commands are not accessible
- `env-configure-gh` - Configure GitHub CLI (requires Git to be configured first)
