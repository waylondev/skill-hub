---
name: env-configure-confluence-cli
description: >-
  Use this skill when the user wants to configure Confluence CLI with internal network host and authentication token.
version: 1.0.0
displayName: Configure Confluence CLI
domain: env
action: configure
object: confluence-cli
tags: [env, confluence, cli, config, internal]
type: SKILL
inputs:
  - name: host
    type: string
    required: true
    description: Internal Confluence host URL
  - name: token
    type: string
    required: true
    description: Authentication token for Confluence API access
---
# Configure Confluence CLI

## Purpose

Configure Confluence CLI with internal network host and authentication token only. Does not handle Confluence CLI installation.

## Trigger Conditions

Use this Skill when:
- Confluence CLI is installed and needs initial configuration
- User needs to connect to internal Confluence instance
- User needs to configure or update authentication token
- User wants to switch to a different Confluence instance

## Prerequisites

- Confluence CLI is installed
- User has valid Confluence account and API token
- User has network access to internal Confluence instance

## Execution Steps

### Step 1: Verify Prerequisites

Before attempting configuration:
- Check if Confluence CLI is installed
- If not found, inform user that Confluence CLI needs to be installed first
- Stop and do not proceed if prerequisites are not met

### Step 2: Validate Input Parameters

Before making changes:
- **Validate host URL format**: Ensure the provided host is a valid URL
- **Validate token format**: Ensure the token is not empty
- If validation fails, inform user with specific error message and stop

### Step 3: Check Current Configuration (Idempotency)

Before making changes:
- Check if Confluence CLI is already configured
- Get current host configuration from Confluence CLI config file
- If already configured with the same host, inform user no changes needed and stop

### Step 4: Initialize Confluence CLI

Configure Confluence CLI environment:
- Run Confluence CLI initialization
- Configure the internal host URL in Confluence CLI configuration
- Configure the authentication token in Confluence CLI configuration
- Save configuration to Confluence CLI config file

### Step 5: Verify Configuration

After configuration:
- Test connection to Confluence instance
- Verify authentication works by making a simple API call
- Confirm configuration is saved correctly
- Display configured host URL (mask token for security)

### Step 6: Inform User

- Confirm Confluence CLI has been configured successfully
- Provide the configured host URL
- Explain how to use Confluence CLI with basic commands
- Mention common Confluence CLI operations (list spaces, get pages, etc.)
- Remind user that token is stored securely and should not be shared

## Constraints

- **Single Responsibility**: Only configures Confluence CLI environment. Does not install Confluence CLI or manage Confluence content.
- **Idempotent**: Check first, configure only if needed. If already configured correctly, do nothing.
- **Prerequisite Check**: If Confluence CLI is not installed, inform user and stop. Do not attempt installation.
- Token should be stored securely by Confluence CLI, do not log or display tokens in plain text
- User-level configuration only (not system-wide)
- Does not handle Confluence Cloud vs Server differences - user must provide appropriate host

## Error Handling

- **CLI not installed**: Inform user Confluence CLI is not installed
- **Invalid host URL**: Inform user provided host URL format is invalid
- **Host unreachable**: Inform user cannot connect to Confluence host, verify network and URL
- **Invalid token**: Inform user token is invalid or expired
- **Authentication failed**: Inform user authentication failed, verify token permissions
- **Already configured**: Inform user Confluence CLI is already configured correctly
- **Network/firewall issue**: Inform user cannot reach Confluence instance, check network and firewall
