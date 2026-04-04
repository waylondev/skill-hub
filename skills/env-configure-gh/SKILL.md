---
name: env-configure-gh
description: >-
  Use this skill when the user wants to configure GitHub CLI (gh) for command-line GitHub operations.
version: 1.0.0
displayName: Configure GitHub CLI
domain: env
action: configure
object: gh
tags: [env, github, cli, gh, scm]
type: SKILL
inputs:
  - name: github_host
    type: string
    required: false
    description: GitHub Enterprise server hostname (optional, uses github.com if not specified)
  - name: auth_method
    type: string
    required: false
    description: Authentication method preference - 'browser' for interactive or 'token' for manual
---
# Configure GitHub CLI

## Purpose

Configure GitHub CLI (gh) for authenticated command-line operations with GitHub, including repository management, pull requests, issues, and GitHub Actions.

## Trigger Conditions

Use this Skill when:
- User has GitHub CLI installed and needs to authenticate
- User needs to configure GitHub Enterprise access
- User wants to enable gh commands for GitHub operations
- Setting up development environment with GitHub integration

## Prerequisites

- Git is installed and configured
- GitHub CLI (gh) is installed on the system
- User has a GitHub account

## Execution Steps

### Step 1: Verify GitHub CLI Installation

Before configuration:
- Check if gh is installed and accessible from command line
- Verify gh version for compatibility
- If not installed, inform user and suggest installation

### Step 2: Authenticate with GitHub

Guide the authentication process:
- Initiate gh auth login command
- Support both GitHub.com and GitHub Enterprise authentication
- If `github_host` is provided, configure for Enterprise instance
- If `auth_method` is 'browser', enable interactive browser authentication
- If `auth_method` is 'token', guide manual token entry

### Step 3: Configure Git Integration

After authentication:
- Configure gh to work with Git operations
- Set up credential helper for Git operations with GitHub
- Ensure seamless integration between gh and git commands

### Step 4: Verify Configuration

After setup:
- Check authentication status with gh auth status
- Verify user is properly authenticated
- Test basic gh command to confirm functionality
- Display authenticated user and host information

### Step 5: Inform User

- Confirm GitHub CLI has been configured successfully
- Explain available gh commands and capabilities
- Provide guidance on common operations (creating PRs, managing issues, etc.)
- Mention how to configure additional GitHub Enterprise instances if needed

## Constraints

- Only responsible for GitHub CLI configuration, not installation
- Requires active GitHub account (personal or enterprise)
- Idempotent: check if already authenticated, skip re-authentication if configured correctly
- For GitHub Enterprise, requires correct enterprise URL
- Authentication tokens are stored securely by gh, do not manage tokens directly

## Error Handling

- **gh not installed**: Inform user to install GitHub CLI first, provide installation guidance
- **Authentication failed**: Guide user through troubleshooting - check network, credentials, or token validity
- **GitHub Enterprise unreachable**: Verify the enterprise hostname is correct and accessible from user's network
- **Git not configured**: Inform user that Git must be configured first for full functionality

## Related Skills

- `env-configure-git` - Configure Git (prerequisite for GitHub CLI)
- `env-configure-path` - Configure PATH if gh commands are not accessible
