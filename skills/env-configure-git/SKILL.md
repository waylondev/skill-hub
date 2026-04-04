---
name: env-configure-git
description: >-
  Use this skill when the user wants to configure Git, set up Git username, or configure Git email.
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
    description: Git username
  - name: user_email
    type: string
    required: true
    description: Git email
  - name: default_branch
    type: string
    required: false
    description: Default branch name (use system default if not specified)
---
# Configure Git

## Trigger Conditions
Use when Git is installed and needs to be configured with username, email, and other basic settings.

## Prerequisites
- Git is installed

## Execution Steps
1. Configure username and email:
   ```bash
   git config --global user.name "{{user_name}}"
   git config --global user.email "{{user_email}}"
   ```

2. Configure default branch name (optional):
   ```bash
   git config --global init.defaultBranch {{default_branch}}
   ```

3. Configure credential helper:
   **Windows (PowerShell):**
   ```powershell
   git config --global credential.helper manager-core
   ```

   **macOS:**
   ```bash
   git config --global credential.helper osxkeychain
   ```

   **Linux:**
   ```bash
   git config --global credential.helper store
   ```

4. Verify configuration:
   ```bash
   git config --global --list
   ```

## Constraints
- Only responsible for Git configuration, not installation
- Email must be company email
- Idempotent: check if correctly configured if already set, do not reconfigure
