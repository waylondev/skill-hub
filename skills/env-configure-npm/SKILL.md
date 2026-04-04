---
name: env-configure-npm
description: >-
  Use this skill when the user wants to configure npm registry URL only.
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
    description: npm registry URL to configure
---
# Configure npm Registry

## Purpose

Configure npm registry URL only. Does not handle authentication or token management.

## Trigger Conditions

Use this Skill when:
- User needs to set npm registry URL
- User wants to switch to a different registry (e.g., internal Nexus/Artifactory)

## Prerequisites

- Node.js and npm are installed on the system

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- **Check if npm is installed**: Run `npm --version`. If npm is not found, inform user: "npm is not installed. Please install Node.js and npm first." Stop and do not proceed.
- If prerequisites are not met, inform user and stop.

### Step 2: Validate Registry URL

- Verify the provided `registry_url` is a valid URL format
- If invalid, inform user: "The provided registry URL is not valid. Please provide a valid URL." and stop.

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Get current npm registry: `npm config get registry`
- If current registry equals `registry_url`, inform user: "npm registry is already set to {{registry_url}}. No changes needed." and stop.

### Step 4: Configure npm Registry

Set the npm registry:
- Use appropriate configuration method for the environment
- Apply at user level (typically ~/.npmrc or equivalent)

### Step 5: Verify Configuration

After configuration:
- Verify registry is correctly set: `npm config get registry`
- Confirm it matches the provided `registry_url`

### Step 6: Inform User

- Confirm npm registry has been configured to {{registry_url}}
- If authentication is needed for this registry, inform user: "This registry may require authentication. Use your organization's credentials or token to authenticate."

## Constraints

- **Single Responsibility**: Only configures registry URL. Does not handle authentication, tokens, or scoped registries.
- **Idempotent**: Check first, configure only if different. If already set correctly, do nothing.
- **Prerequisite Check**: If npm is not installed, inform user and stop.
- User-level configuration only (~/.npmrc)

## Error Handling

- **npm not installed**: "npm is not installed. Please install Node.js and npm first."
- **Invalid URL**: "The provided registry URL is not valid. Please provide a valid URL."
- **Already configured**: "npm registry is already set to {{registry_url}}. No action needed."
- **Registry unreachable**: "The registry at {{registry_url}} is not accessible. Please check your network connection or firewall settings."

## Related Skills

- `env-configure-nodejs` - Configure Node.js environment (prerequisite)
- `env-configure-pnpm` - Configure pnpm (uses same .npmrc file)
