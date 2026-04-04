---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git with username, email, and other basic settings.
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
  - name: default_branch
    type: string
    required: false
    description: Default branch name for new repositories (uses system default if not specified)
---
# Configure Git

## Trigger Conditions

Use this Skill when:
- Git is installed and needs initial configuration
- User needs to set up Git username and email for commits
- User wants to configure Git credential helper
- User needs to set default branch name for new repositories

## Prerequisites

- Git is installed on the system
- User has appropriate permissions to modify Git configuration

## Execution Steps

### Step 1: Verify Git Installation

Before configuring:
- Verify Git is installed and accessible from command line
- Check Git version to ensure compatibility
- If Git is not installed, inform user and suggest installation

### Step 2: Configure Git Username

Set the global username that will appear in commits:
- Use the `user.name` configuration key
- Apply at global level (affects all repositories for this user)
- If already configured correctly, skip this step (idempotent)

### Step 3: Configure Git Email

Set the email address that will be associated with commits:
- Use the `user.email` configuration key
- Apply at global level
- Ensure the email format is valid
- If already configured correctly, skip this step (idempotent)

### Step 4: Configure Default Branch Name (Optional)

If `default_branch` parameter is provided:
- Set the default branch name for new repositories
- Use the `init.defaultBranch` configuration key
- Common values: "main", "master", or organization standard
- If not provided, use Git's default behavior

### Step 5: Configure Credential Helper

Set up Git credential helper based on the operating system:

**Windows:**
- Use Windows Credential Manager for secure credential storage
- Configure Git to use the credential manager helper

**macOS:**
- Use macOS Keychain for secure credential storage
- Configure Git to use the osxkeychain helper

**Linux:**
- Options include credential cache or plain text storage
- Configure based on security requirements and distribution

### Step 6: Verify Configuration

After configuration:
- List all Git configuration to verify settings
- Confirm username and email are correctly set
- Confirm credential helper is configured
- Optionally, test with a dry-run Git operation

### Step 7: Inform User

- Confirm Git has been configured successfully
- Provide summary of configured settings
- Remind user that these settings apply globally
- If needed, explain how to override settings for specific repositories

## Constraints

- Only responsible for Git configuration, not Git installation
- Email should be the user's company email for work repositories
- Idempotent: check if correctly configured, do not reconfigure if already set properly
- Configuration is at global level (~/.gitconfig), not repository-specific
- Do not overwrite existing custom configurations without user confirmation

## Error Handling

- **Git not installed**: Inform user to install Git first, provide installation guidance
- **Invalid email format**: If provided email doesn't look valid, warn user but still configure
- **Configuration file locked**: If .gitconfig cannot be written, inform user about file permissions
- **Existing configuration conflict**: If settings differ from what user wants, inform about the change before applying

## Related Skills

- `env-configure-path` - Configure PATH if Git commands are not accessible
- `sn-request-software` - Request Git installation if not available
