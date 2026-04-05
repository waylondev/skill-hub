---
name: dev-create-remote-repo
description: >-
  Use this skill when the user wants to create a remote Git repository,
  initialize a new repository on GitHub/GitLab, or set up a remote repository for a project.
version: 1.0.0
displayName: Create Remote Git Repository
domain: dev
action: create
object: remote-repo
tags: [git, repository, github, gitlab, repo]
type: SKILL
inputs:
  - name: repo_name
    type: string
    required: true
    description: Name of the repository to create
  - name: repo_description
    type: string
    required: false
    description: Description of the repository
  - name: private
    type: boolean
    required: false
    description: Whether the repository should be private (default: true)
  - name: platform
    type: string
    required: false
    description: Git platform (github, gitlab, etc. - defaults to configured platform)
  - name: initialize_readme
    type: boolean
    required: false
    description: Whether to initialize with a README.md (default: false)
---
# Create Remote Git Repository

## Purpose

Create a remote Git repository only. Does not handle local repository setup or code commits.

## Trigger Conditions

Use this Skill when:
- User wants to create a new remote Git repository
- User wants to initialize a repository on GitHub/GitLab
- User wants to set up a remote repository for a new project

## Prerequisites

- Git CLI or platform CLI (gh, glab, etc.) is installed and authenticated
- User has permission to create repositories on the target platform

## Execution Steps

### Step 1: Verify Prerequisites

Before proceeding:
- Check if Git or platform CLI is installed and authenticated
- If not installed or authenticated, inform user and stop

### Step 2: Validate Input Parameters

Before creating:
- Validate {{repo_name}} is valid (no special characters, not empty)
- If invalid, inform user and stop

### Step 3: Check if Repository Already Exists

Before creating:
- Check if a repository with {{repo_name}} already exists on the platform
- If it exists, inform user and stop (idempotent)

### Step 4: Create Remote Repository

Create the remote repository:
- Use the appropriate platform CLI or API
- Pass all provided parameters:
  - Repository name: {{repo_name}}
  - Description: {{repo_description}} (if provided)
  - Private: {{private}} (if provided)
  - Platform: {{platform}} (if provided)
  - Initialize README: {{initialize_readme}} (if provided)
- Capture creation output
- Check for successful completion

### Step 5: Verify Repository Creation

After creation:
- Verify the repository was created successfully
- Get the repository URL
- If successful, inform user and provide the repository URL
- If failed, display error message

## Constraints

- **Single Responsibility**: Only creates remote repository. Does not handle local setup or code commits.
- **Idempotent**: Check if repository exists before creating. Do not create duplicates.
- **Prerequisite Check**: If CLI not installed or authenticated, inform user and stop.
- **User-level only**: Creates repository with current user permissions only.

## Error Handling

- **CLI not installed**: Inform user Git or platform CLI is not installed
- **Not authenticated**: Inform user CLI is not authenticated with the platform
- **Invalid repository name**: Inform user repository name is invalid
- **Repository already exists**: Inform user repository already exists
- **Creation failed**: Inform user repository creation failed with error message
