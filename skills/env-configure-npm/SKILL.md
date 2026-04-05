---
name: env-configure-npm
description: >-
  Configure npm registry URL.
  Invoke when user needs to switch npm registry (e.g., to internal Nexus/Artifactory).
  Idempotent configuration (checks before applying).
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
- Check if npm is installed
- If not installed, inform user and stop

### Step 2: Validate Registry URL

- Verify the provided `registry_url` is a valid URL format
- If invalid, inform user and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Get current npm registry
- If current registry equals `registry_url`, inform user and stop

### Step 4: Configure npm Registry

Set the npm registry:
- Apply at user level (user's npm configuration file)

### Step 5: Verify Configuration

After configuration:
- Verify registry is correctly set
- Confirm it matches the provided `registry_url`

### Step 6: Inform User

- Confirm npm registry has been configured
- If authentication is needed for this registry, inform user

## Constraints

- **Single Responsibility**: Only configures registry URL, not authentication, tokens, or scoped registries
- **Idempotent**: Check first, configure only if different
- **Prerequisite Check**: If npm is not installed, inform user and stop
- User-level configuration only

## Error Handling

- **npm not installed**: Inform user npm is not installed, need to install Node.js and npm first
- **Invalid URL**: Inform user provided registry URL is not valid
- **Already configured**: Inform user npm registry is already set correctly
- **Registry unreachable**: Inform user registry is not accessible, check network or firewall
