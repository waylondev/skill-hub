---
name: env-configure-pnpm
description: >-
  Use this skill when the user wants to configure pnpm, set up .npmrc, or configure pnpm registry.
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
    required: true
    description: npm registry URL
  - name: npm_token
    type: string
    required: false
    description: Private repository token
---
# Configure pnpm

## Trigger Conditions
Use when configuring pnpm package manager.

## Prerequisites
- Node.js is configured

## Execution Steps
1. Configure .npmrc (for pnpm use):
   Location: ~/.npmrc (macOS / Linux) or %USERPROFILE%\.npmrc (Windows)
   ```ini
   registry={{registry}}
   auto-install-peers=true
   strict-peer-dependencies=false
   shamefully-hoist=true
   store-dir=~/.pnpm-store
   ```

## Constraints
- Only responsible for pnpm configuration, not installation
- Idempotent: check if correctly configured if already set, do not reconfigure
