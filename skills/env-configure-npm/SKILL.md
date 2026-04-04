---
name: env-configure-npm
description: >-
  Use this skill when the user wants to configure npm registry settings and authentication for package management.
version: 1.0.0
displayName: Configure npm Registry
domain: env
action: configure
object: npm
tags: [env, npm, nodejs, config, registry]
type: SKILL
inputs:
  - name: registry_url
    type: string
    required: true
    description: npm registry URL (public or private repository)
  - name: scope
    type: string
    required: false
    description: Package scope for scoped registry configuration (optional)
  - name: always_auth
    type: boolean
    required: false
    description: Whether to always send authentication (default: true for private registries)
---
# Configure npm Registry

## Purpose

Configure npm package manager to use custom registry (public or private) for dependency installation and publishing.

## Trigger Conditions

Use this Skill when:
- User needs to configure npm to use internal/private registry
- Setting up development environment with corporate Nexus/Artifactory
- User needs to configure scoped package registries
- Configuring authentication for private npm packages

## Prerequisites

- Node.js and npm are installed on the system
- User has access to the target npm registry
- If private registry, user has authentication credentials

## Execution Steps

### Step 1: Validate Registry URL

Before configuration:
- Verify the provided registry URL is valid format
- Check if registry is accessible from user's network
- If registry is unreachable, inform user

### Step 2: Configure npm Registry

Set the npm registry:
- Use npm config set command or update .npmrc file
- If `scope` is provided, configure scoped registry
- If `always_auth` is true, configure authentication requirement
- Apply configuration at user level (~/.npmrc)

### Step 3: Configure Authentication (if needed)

For private registries:
- Guide user through authentication setup
- Support npm token authentication
- Support .npmrc credential configuration
- Never store credentials in plain text in Skill files

### Step 4: Verify Configuration

After configuration:
- Verify registry is correctly set: npm config get registry
- Test npm can access registry: npm ping or npm whoami
- Display current npm configuration summary
- If scoped registry, verify scope configuration

### Step 5: Inform User

- Confirm npm registry has been configured successfully
- Provide registry URL that was configured
- Explain how to install packages from the configured registry
- If private registry, remind about token refresh requirements

## Constraints

- Only responsible for npm registry configuration, not npm installation
- Idempotent: check if correctly configured, do not rewrite if already set properly
- Use user-level configuration (~/.npmrc), not global
- Do not hardcode credentials - guide user to obtain and store securely
- Support both global registry and scoped registry configurations

## Error Handling

- **npm not found**: Inform user to install Node.js and npm first
- **Registry URL invalid**: If provided URL is not valid format, ask user to verify
- **Registry unreachable**: If registry cannot be accessed, inform user to check network/firewall settings
- **Authentication failed**: Guide user to verify credentials or obtain new token

## Related Skills

- `env-configure-nodejs` - Configure Node.js environment (prerequisite)
- `env-configure-pnpm` - Configure pnpm (alternative package manager)
- `env-configure-path` - Generic path configuration if npm commands not accessible
