---
name: env-configure-pnpm
description: >-
  Use this skill when the user wants to configure pnpm package manager settings and registry.
version: 1.0.0
displayName: Configure pnpm
domain: env
action: configure
object: pnpm
tags: [env, pnpm, package, config]
type: SKILL
inputs:
  - name: registry
    type: string
    required: false
    description: npm registry URL (uses npm's default if not specified)
  - name: store_dir
    type: string
    required: false
    description: Custom pnpm store directory (optional, uses default if not specified)
  - name: auto_install_peers
    type: boolean
    required: false
    description: Enable auto-install of peer dependencies (default: true)
---
# Configure pnpm

## Purpose

Configure pnpm package manager with registry settings and optimization options for efficient package management.

## Trigger Conditions

Use this Skill when:
- User has pnpm installed and needs initial configuration
- User wants to configure custom registry for pnpm
- User needs to optimize pnpm store location
- Setting up pnpm for enterprise development environment

## Prerequisites

- Node.js and npm are installed on the system
- pnpm is installed (or will be installed via npm)

## Execution Steps

### Step 1: Verify pnpm Installation

Before configuration:
- Check if pnpm is installed and accessible
- Verify pnpm version for compatibility
- If not installed, inform user pnpm can be installed via npm

### Step 2: Configure Registry (Optional)

If `registry` parameter is provided:
- Set the npm registry URL for pnpm
- Update .npmrc file (pnpm uses npm's configuration)
- If not provided, use npm's default registry

### Step 3: Configure Store Directory (Optional)

If `store_dir` parameter is provided:
- Set custom pnpm store directory location
- This controls where pnpm stores global package cache
- Useful for systems with limited default disk space
- Update pnpm configuration file

### Step 4: Configure Peer Dependencies (Optional)

If `auto_install_peers` parameter is provided:
- Enable or disable automatic peer dependency installation
- If true, pnpm automatically installs peer dependencies
- If false, user must manually install peer dependencies
- Update pnpm configuration file

### Step 5: Verify Configuration

After configuration:
- Display current pnpm configuration
- Verify registry is correctly set
- Confirm store directory if customized
- Test pnpm can install packages

### Step 6: Inform User

- Confirm pnpm has been configured successfully
- Explain pnpm's disk space advantages over npm
- Provide guidance on common pnpm commands
- Mention how to verify configuration in pnpm-workspace.yaml if using monorepo

## Constraints

- Only responsible for pnpm configuration, not installation
- pnpm uses .npmrc file (same as npm) for configuration
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Do not hardcode specific registry URLs or paths
- Configuration applies to both pnpm and npm (shared .npmrc)

## Error Handling

- **pnpm not found**: Inform user to install pnpm first (can install via npm install -g pnpm)
- **Registry unreachable**: If provided registry cannot be accessed, inform user to check network settings
- **Store directory not writable**: If cannot write to store directory, suggest alternative location
- **Configuration file locked**: If .npmrc cannot be written, inform user about file permissions

## Related Skills

- `env-configure-nodejs` - Configure Node.js environment (prerequisite)
- `env-configure-npm` - Configure npm registry (shares configuration)
- `env-configure-path` - Generic path configuration if pnpm commands not accessible
