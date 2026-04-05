---
name: dev-generate-code-from-oas
description: >-
  Use this skill when the user wants to generate code from an OpenAPI Specification (OAS) file,
  create API client/server code from OAS, or generate project artifacts from an OpenAPI definition.
version: 1.0.0
displayName: Generate Code from OpenAPI Specification
domain: dev
action: generate
object: code-from-oas
tags: [openapi, oas, code-generation, api]
type: SKILL
inputs:
  - name: oasFileLocation
    type: string
    required: true
    description: Path to the OpenAPI Specification (OAS) file
  - name: outputLocation
    type: string
    required: true
    description: Output directory for the generated code
  - name: groupId
    type: string
    required: true
    description: Maven group ID for the generated project
  - name: artifactId
    type: string
    required: true
    description: Maven artifact ID for the generated project
  - name: githubToken
    type: string
    required: true
    description: GitHub token for authentication
  - name: generatorJarPath
    type: string
    required: false
    description: Path to OAS code generator JAR (defaults to bin/oas-codegen.jar)
  - name: mavenHome
    type: string
    required: false
    description: Path to Maven home directory (auto-detect if not specified)
  - name: sapiId
    type: string
    required: false
    description: Optional SAPI ID for the generated code
---
# Generate Code from OpenAPI Specification

## Purpose

Generate code from an OpenAPI Specification (OAS) file only. Does not handle code customization or manual modifications after generation.

## Trigger Conditions

Use this Skill when:
- User wants to generate code from an OpenAPI Specification file
- User wants to create API client/server code from OAS
- User wants to generate project artifacts from an OpenAPI definition
- User wants to regenerate code from an updated OAS file

## Prerequisites

- Java is installed and available in PATH
- OAS code generator JAR exists (at `bin/oas-codegen.jar` or user-specified location)
- OAS file exists at the specified location

## Execution Steps

### Step 1: Determine Generator JAR Path

Determine the path to the OAS code generator JAR:
- If `{{generatorJarPath}}` is provided, use that path
- If not provided, use the default path: `bin/oas-codegen.jar`

### Step 2: Verify Prerequisites

Before proceeding:
- Check if Java is installed and available
- Check if OAS code generator JAR exists at the determined path
- Check if OAS file exists at {{oasFileLocation}}
- If any prerequisite fails, inform user and stop

### Step 3: Validate Input Parameters

Before generating:
- Validate {{oasFileLocation}} exists and is a valid OAS file
- Validate {{outputLocation}} is a valid directory path or can be created
- Validate {{groupId}} and {{artifactId}} are valid Maven identifiers
- Validate {{githubToken}} is not empty
- If {{mavenHome}} is provided, validate it is a valid Maven installation directory
- If any validation fails, inform user and stop

### Step 4: Check if Output Already Exists

Before generating:
- Check if {{outputLocation}} directory already exists
- If it exists and is not empty, inform user and stop (avoid overwriting existing code)

### Step 5: Generate Code from OAS

Run the OAS code generator:
- Use the OAS code generator JAR at the determined path
- Pass all provided parameters:
  - `--oasFile={{oasFileLocation}}`
  - `--output={{outputLocation}}`
  - `--groupId={{groupId}}`
  - `--artifactId={{artifactId}}`
  - `--githubToken={{githubToken}}`
  - `--mavenHome={{mavenHome}}` (if provided)
  - `--sapiId={{sapiId}}` (if provided)
- Capture generation output and display progress
- Check for successful completion (exit code 0)

### Step 6: Verify Generated Code

After generation:
- Verify code was generated at {{outputLocation}}
- Check standard project files are present (pom.xml, README.md, src directory, etc.)
- Validate project structure matches expectations
- If successful, inform user; if failed, display error

## Constraints

- **Single Responsibility**: Only generates code from OAS file. Does not handle code customization or manual modifications.
- **Idempotent**: Check if output directory exists before generating. Do not overwrite existing code.
- **Prerequisite Check**: If Java, generator, or OAS file not found, inform user and stop.
- **User-level only**: Generates code with current user permissions only. Does not modify system-wide configurations.

## Error Handling

- **Java not installed**: Inform user Java is not installed
- **Generator JAR not found**: Inform user OAS code generator JAR not found at {{generatorJarPath}} (or bin/oas-codegen.jar if not specified)
- **OAS file not found**: Inform user OAS file not found at {{oasFileLocation}}
- **GitHub token is empty**: Inform user GitHub token cannot be empty
- **Invalid Maven home**: Inform user provided Maven home is invalid
- **Invalid Maven identifiers**: Inform user {{groupId}} or {{artifactId}} are invalid
- **Output directory already exists**: Inform user output directory already exists
- **Code generation failed**: Inform user code generation failed with error message
