---
name: sn-request-software
description: >-
  Use this skill when the user wants to request software installation (Java, IDE, Node.js, etc.) via ServiceNow.
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
    description: Software name
  - name: applicant
    type: string
    required: true
    description: Applicant name or employee ID
  - name: reason
    type: string
    required: true
    description: Application reason
  - name: version
    type: string
    required: false
    description: Specified version (optional)
---
# ServiceNow Request Software

Submit software installation application in ServiceNow, which will be pushed to Software Center after approval.

## Prerequisites
- Software must be provided by company Software Center
- If not provided, confirm whether software is in available list first

## Execution Steps
1. Confirm application information: {{software_name}}, applicant {{applicant}}, version {{version}}
2. Check if already applied to avoid duplication
3. If not applied, submit new application in ServiceNow
4. Fill in application information and submit
5. Inform user of approval process and time

## Constraints
- Only responsible for ServiceNow application, not installation
- Idempotent: inform status if already applied, do not resubmit
- Approval time: 1-2 business days
