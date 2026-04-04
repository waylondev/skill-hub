---
name: swc-install-package
description: >-
  Use this skill when the user wants to install approved software packages in Software Center.
version: 1.0.0
displayName: Software Center Install Software
domain: swc
action: install
object: package
tags: [software-center, install, package]
type: SKILL
inputs:
  - name: package_name
    type: string
    required: true
    description: Software package name
---
# Software Center Install Software

Install approved software packages in Software Center.

## Prerequisites
- Software must be approved in ServiceNow
- Software must be pushed to Software Center
- If not approved, use sn-request-software to submit application first

## Execution Steps
1. Confirm software name: {{package_name}}
2. Open Software Center
3. Search for {{package_name}}
4. Click "Install"
5. Wait for installation to complete, confirm status is "Installed"

## Constraints
- Only responsible for Software Center installation, not application
- Not responsible for environment variable configuration (use env-configure-*)
- Idempotent: inform if already installed
