---
name: sn-request-software
description: >-
  Use this skill when the user wants to request software installation via ServiceNow.
version: 1.0.0
displayName: ServiceNow Request Software
domain: sn
action: request
object: software
tags: [servicenow, software, apply, install]
type: SKILL
inputs:
  - name: software_name
    type: string
    required: true
    description: Software name to request
  - name: applicant
    type: string
    required: true
    description: Applicant name or employee ID
  - name: reason
    type: string
    required: true
    description: Business justification for the request
  - name: version
    type: string
    required: false
    description: Specific version if required (optional)
---
# ServiceNow Request Software

Submit software installation request through ServiceNow portal. After approval, software will be available in Software Center.

## Trigger Conditions

Use this Skill when:
- User needs to request software installation
- Software is provided through company Software Center
- User needs to go through approval process

## Prerequisites

- User has access to ServiceNow portal
- Requested software is available in the company's approved software list
- If software is not in the list, verify availability first

## Execution Steps

### Step 1: Gather Request Information

Collect required information:
- Software name (what the user wants to install)
- Applicant information (who needs the software)
- Business justification (why it's needed)
- Version preference (if specific version is required)

### Step 2: Check Existing Requests

Before submitting new request:
- Search for existing requests for the same software by the same applicant
- Check request status (pending, approved, rejected)
- If approved request exists, inform user they can proceed to installation
- If pending request exists, inform user of the status and estimated approval time

### Step 3: Navigate to Software Request Portal

- Access the company ServiceNow portal
- Navigate to the software request form/catalog item
- Ensure user is authenticated with proper credentials

### Step 4: Fill in Request Form

Complete all required fields:
- Select the requested software from available options
- Enter applicant information
- Provide business justification
- Specify version if needed
- Fill in any additional required fields based on the form

### Step 5: Submit Request

- Review all entered information for accuracy
- Submit the request
- Record the request/ticket number for tracking

### Step 6: Inform User

After submission:
- Provide the request/ticket number
- Explain the approval workflow
- Give estimated approval timeline
- Explain next steps (what happens after approval)
- Mention that email notification will be sent

## Constraints

- Only responsible for ServiceNow request submission, not software installation
- Idempotent: if existing approved request found, inform status instead of resubmitting
- Do not guarantee approval - approval depends on company policies and approvers
- Only request software that is available in the company's approved list
- Respect user's privacy - do not share applicant information unnecessarily

## Error Handling

- **Software not found in catalog**: Inform user that the requested software may not be available, suggest checking the approved software list
- **Insufficient permissions**: If user cannot access the request form, inform them about permission requirements
- **Request rejected**: If previous request was rejected, inform user of the rejection reason if available, suggest addressing the issue before resubmitting
- **Duplicate request detected**: Inform user about existing request, provide ticket number and status
