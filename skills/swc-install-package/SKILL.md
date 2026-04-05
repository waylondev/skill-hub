---
name: swc-install-package
description: >-
  Use this skill when the user wants to install approved software packages through Software Center.
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
    description: Name of the software package to install
---
# Software Center Install Software

Install approved software packages through the company Software Center application.

## Trigger Conditions

Use this Skill when:
- User has an approved software request
- Software is available in Software Center
- User needs to install the software on their machine

## Prerequisites

- Software request has been approved in ServiceNow
- Software has been pushed to Software Center
- User has appropriate permissions to install software
- If not approved, use `sn-request-software` to submit request first

## Execution Steps

### Step 1: Verify Installation Prerequisites

Before attempting installation:
- Confirm the software request has been approved
- Verify the software is available in Software Center
- Check if the software is already installed (avoid redundant installation)

### Step 2: Open Software Center

- Launch the Software Center application on the user's machine
- Ensure the application loads successfully
- Verify user can see available software

### Step 3: Locate the Software

- Search for the software by name in Software Center
- Use appropriate search terms based on the package name
- If multiple results appear, identify the correct one based on software name and publisher

### Step 4: Initiate Installation

- Select the software from search results
- Click the Install button
- If prompted, confirm installation or accept license agreement
- Monitor installation progress

### Step 5: Wait for Installation Complete

- Wait for the installation process to finish
- Monitor installation status (Installing → Installed)
- If installation fails, note the error message

### Step 6: Verify Installation

After installation completes:
- Confirm the software shows as installed in Software Center
- Optionally, verify the software can be launched
- Check that the software is functional

### Step 7: Inform User

- Confirm successful installation
- Provide any post-installation guidance (e.g., may need to restart, configure environment variables)
- If environment variables need configuration, suggest using appropriate `env-configure-*` Skill
- Inform user where to find the installed software (Start menu, Applications folder, etc.)

## Constraints

- Only responsible for Software Center installation operation, not software request/approval
- Not responsible for environment variable configuration after installation (use `env-configure-*` Skills)
- Idempotent: if software is already installed, inform user instead of reinstalling
- Only install software that has been approved and is available in Software Center
- Do not install software from other sources (this Skill is specifically for Software Center)

## Error Handling

- **Software not found in Software Center**: Inform user that the software may not be available yet, suggest checking if request is approved
- **Installation failed**: Report the error message, suggest checking system requirements or contacting IT support
- **Insufficient permissions**: Inform user that they may need admin rights or the software needs to be deployed as user-installable
- **Already installed**: Inform user that the software is already installed, provide location or offer to launch it
- **Software Center unavailable**: If Software Center application cannot be opened, inform user about the issue and suggest troubleshooting steps

## Related Skills

- `sn-request-software` - Request software approval in ServiceNow before installation
- `env-configure-java` - Configure Java environment after Java installation
- `env-configure-nodejs` - Configure Node.js environment after Node installation
- `env-configure-maven` - Configure Maven environment after Maven installation
