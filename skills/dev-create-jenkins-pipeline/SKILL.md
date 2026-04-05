---
name: dev-create-jenkins-pipeline
description: >-
  Use this skill when the user wants to create a Jenkins pipeline,
  set up a new CI/CD pipeline in Jenkins, or configure a job for a project.
version: 1.0.0
displayName: Create Jenkins Pipeline
domain: dev
action: create
object: jenkins-pipeline
tags: [jenkins, pipeline, ci, cd, job]
type: SKILL
inputs:
  - name: pipeline_name
    type: string
    required: true
    description: Name of the Jenkins pipeline/job to create
  - name: pipeline_type
    type: string
    required: true
    description: Type of pipeline (freestyle, pipeline, multibranch, etc.)
  - name: repo_url
    type: string
    required: true
    description: URL of the Git repository for the pipeline
  - name: jenkinsfile_path
    type: string
    required: false
    description: Path to Jenkinsfile in the repository (default: Jenkinsfile)
  - name: branch
    type: string
    required: false
    description: Default branch for the pipeline (default: main)
  - name: folder
    type: string
    required: false
    description: Jenkins folder to create the pipeline in
---
# Create Jenkins Pipeline

## Purpose

Create a Jenkins pipeline only. Does not handle pipeline execution or post-creation configuration.

## Trigger Conditions

Use this Skill when:
- User wants to create a new Jenkins pipeline
- User wants to set up CI/CD for a project
- User wants to configure a new Jenkins job

## Prerequisites

- Jenkins CLI or access to Jenkins API is available
- User has permission to create jobs/pipelines in Jenkins
- Git repository exists and is accessible

## Execution Steps

### Step 1: Verify Prerequisites

Before proceeding:
- Check if Jenkins CLI or API access is available
- Check if user has permission to create pipelines
- If any prerequisite fails, inform user and stop

### Step 2: Validate Input Parameters

Before creating:
- Validate {{pipeline_name}} is valid (no special characters, not empty)
- Validate {{repo_url}} is a valid Git repository URL
- If invalid, inform user and stop

### Step 3: Check if Pipeline Already Exists

Before creating:
- Check if a pipeline/job with {{pipeline_name}} already exists in Jenkins
- If it exists, inform user and stop (idempotent)

### Step 4: Create Jenkins Pipeline

Create the Jenkins pipeline:
- Use Jenkins CLI or API
- Pass all provided parameters:
  - Pipeline name: {{pipeline_name}}
  - Pipeline type: {{pipeline_type}}
  - Repository URL: {{repo_url}}
  - Jenkinsfile path: {{jenkinsfile_path}} (if provided)
  - Default branch: {{branch}} (if provided)
  - Folder: {{folder}} (if provided)
- Capture creation output
- Check for successful completion

### Step 5: Verify Pipeline Creation

After creation:
- Verify the pipeline was created successfully
- Get the pipeline URL
- If successful, inform user and provide the pipeline URL
- If failed, display error message

## Constraints

- **Single Responsibility**: Only creates Jenkins pipeline. Does not handle execution or post-creation configuration.
- **Idempotent**: Check if pipeline exists before creating. Do not create duplicates.
- **Prerequisite Check**: If Jenkins access not available or no permission, inform user and stop.
- **User-level only**: Creates pipeline with current user permissions only.

## Error Handling

- **Jenkins access not available**: Inform user Jenkins CLI or API access is not available
- **No permission**: Inform user does not have permission to create pipelines
- **Invalid pipeline name**: Inform user pipeline name is invalid
- **Invalid repository URL**: Inform user repository URL is invalid
- **Pipeline already exists**: Inform user pipeline already exists
- **Creation failed**: Inform user pipeline creation failed with error message
