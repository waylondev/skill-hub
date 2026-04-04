---
name: sn-request-ad-group
description: >-
  Use this skill when the user wants to request access to Active Directory security groups or distribution groups via ServiceNow.
version: 1.0.0
displayName: ServiceNow Request AD Group Permission
domain: sn
action: request
object: ad-group
tags: [servicenow, ad, active-directory, permission, group]
type: SKILL
inputs:
  - name: group_name
    type: string
    required: true
    description: AD group name
  - name: applicant
    type: string
    required: true
    description: Applicant name or employee ID
  - name: reason
    type: string
    required: true
    description: Application reason
  - name: business_justification
    type: string
    required: false
    description: Business justification (optional)
---
# ServiceNow Request AD Group Permission

Submit application in ServiceNow to join specified Active Directory group.

## Prerequisites
- Know the AD group name to apply for
- Sensitive groups (e.g., prod-*) require additional business justification

## Execution Steps
1. Confirm application information: AD group {{group_name}}, applicant {{applicant}}
2. Check if user is already in the group
3. If not in the group, submit new application in ServiceNow
4. Fill in application information and business justification
5. Inform user of approval process and effective time

## Constraints
- Only responsible for ServiceNow application, not direct AD modification
- Idempotent: inform if already in group, do not reapply
- Approval chain: Department Manager → IT Security Team
- Effective time: within 15 minutes after approval
