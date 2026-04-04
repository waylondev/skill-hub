---
name: env-configure-npm
description: >-
  Use this skill when the user wants to configure npm mirror, set up .npmrc, or configure internal Nexus npm registry.
version: 1.0.0
displayName: Configure npm Internal Nexus Mirror
domain: env
action: configure
object: npm
tags: [env, npm, nodejs, config, registry]
type: SKILL
inputs:
  - name: npm_registry_url
    type: string
    required: true
    description: Nexus npm repository URL
---
# Configure npm Internal Nexus Mirror

## Trigger Conditions
Use when configuring npm to use internal Nexus mirror source.

## Prerequisites
- Node.js and npm are installed

## Execution Steps
1. Configure npm registry:
   ```bash
   npm config set registry {{npm_registry_url}}
   npm config set always-auth true
   ```

2. Verify:
   ```bash
   npm config get registry
   npm config list
   ```

## Constraints
- Requires NEXUS_TOKEN or NPM_TOKEN from IT
- Idempotent: check if correctly configured if already set, do not rewrite
