---
name: env-configure-gh
description: >-
  Use this skill when the user wants to configure GitHub CLI, set up gh, or configure GitHub command-line tool.
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
    description: GitHub server address (for enterprise edition, default is github.com)
  - name: auth_method
    type: string
    required: false
    description: Authentication method - browser or token
---
# Configure GitHub CLI

## Trigger Conditions
Use when configuring GitHub CLI (gh) for command-line GitHub operations.

## Prerequisites
- Git is configured
- GitHub CLI is installed

## Execution Steps
1. Check installation status:
   ```bash
   gh --version
   ```

2. Authenticate and login:
   ```bash
   gh auth login
   ```

3. Verify authentication status:
   ```bash
   gh auth status
   ```

## Constraints
- Only responsible for GitHub CLI configuration, not installation
- Requires GitHub account
- Enterprise edition needs correct GitHub Enterprise URL
- Idempotent: check if correctly configured if already set, do not reconfigure
