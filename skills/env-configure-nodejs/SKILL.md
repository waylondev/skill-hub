---
name: env-configure-nodejs
description: >-
  Use this skill when the user wants to configure Node.js environment variables or set up Node environment.
version: 1.0.0
displayName: Configure Node.js Environment Variables
domain: env
action: configure
object: nodejs
tags: [env, nodejs, node, npm, config]
type: SKILL
inputs:
  - name: node_install_path
    type: string
    required: false
    description: Node.js installation path (auto-detect if not specified)
  - name: npm_registry
    type: string
    required: false
    description: Custom npm registry URL (optional, use default if not specified)
---
# Configure Node.js Environment Variables

## Trigger Conditions

Use this Skill when:
- Node.js is installed and needs environment configuration
- User needs to add Node.js to system PATH
- User wants to configure custom npm registry
- User needs to verify Node.js installation

## Prerequisites

- Node.js is installed on the system

## Execution Steps

### Step 1: Detect Node.js Installation

If `node_install_path` parameter is not provided:
- Locate Node.js installation using system-specific methods
- Check common installation directories
- Verify Node.js is accessible from command line
- If multiple versions exist, identify the active version

### Step 2: Add Node.js to PATH

Ensure Node.js executables are accessible:
- Add Node.js installation directory to PATH
- Include both node and npm locations
- Avoid duplicate entries in PATH
- Use appropriate path separator for the platform

### Step 3: Configure npm Registry (Optional)

If `npm_registry` parameter is provided:
- Set the npm registry URL in npm configuration
- Update or create .npmrc file
- If not provided, use npm's default registry

### Step 4: Verify Installation

After configuration:
- Verify Node.js is accessible and returns version
- Verify npm is accessible and returns version
- Confirm PATH configuration is correct

### Step 5: Inform User

- Confirm Node.js environment has been configured
- Provide version information for node and npm
- Remind user that terminal restart may be required for changes to take effect
- Explain how to verify the configuration independently

## Constraints

- Only responsible for environment variable configuration, not Node.js installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Use user-level configuration where possible
- Do not modify global npm configuration without explicit request

## Error Handling

- **Node.js not found**: Inform user to install Node.js first or provide the installation path
- **Invalid installation path**: If provided path doesn't contain node executable, ask user to verify
- **Permission denied**: If cannot write to npm configuration, inform user about permission requirements

## Related Skills

- `env-configure-path` - Generic path configuration alternative
- `env-configure-npm` - Configure npm with internal Nexus registry
- `env-configure-pnpm` - Configure pnpm package manager
