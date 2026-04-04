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
    description: AD group name to request access to
  - name: applicant
    type: string
    required: true
    description: Applicant name or employee ID
  - name: reason
    type: string
    required: true
    description: Business reason for the access request
  - name: business_justification
    type: string
    required: false
    description: Additional business justification (required for sensitive groups)
---
# ServiceNow Request AD Group Permission

Submit Active Directory group access request through ServiceNow portal. After approval, user will be added to the specified AD group.

## Trigger Conditions

Use this Skill when:
- User needs access to an Active Directory security group or distribution group
- User requires permissions that are controlled by AD group membership
- User needs to access resources restricted to specific AD groups

## Prerequisites

- User knows the exact AD group name they need to join
- User has access to ServiceNow portal
- Sensitive groups (e.g., prod-*, admin-*) require additional business justification
- Verify the AD group exists before submitting request

## Execution Steps

### Step 1: Gather Request Information

Collect required information:
- AD group name (exact name of the group)
- Applicant information (who needs access)
- Business reason (why access is needed)
- Additional justification (if sensitive group)

### Step 2: Validate AD Group

Before submitting request:
- Verify the AD group exists in the directory
- Check if the group is a security group or distribution group
- Identify if the group is sensitive (requires additional approval)
- If group doesn't exist, inform user and suggest verifying the group name

### Step 3: Check Existing Membership

- Check if the user is already a member of the AD group
- If already a member, inform user and skip request submission
- Check if there's a pending request for the same group
- If pending request exists, inform user of the status

### Step 4: Navigate to AD Group Request Portal

- Access the company ServiceNow portal
- Navigate to the AD group request form/catalog item
- Ensure user is authenticated with proper credentials

### Step 5: Fill in Request Form

Complete all required fields:
- Enter the AD group name
- Provide applicant information
- Specify business reason for access
- Add additional justification if required (especially for sensitive groups)
- Fill in any additional required fields based on the form

### Step 6: Submit Request

- Review all entered information for accuracy
- Submit the request
- Record the request/ticket number for tracking

### Step 7: Inform User

After submission:
- Provide the request/ticket number
- Explain the approval workflow (Department Manager → IT Security Team)
- Give estimated approval timeline
- Inform user that access will be effective within 15 minutes after approval
- Mention that email notification will be sent upon approval

## Constraints

- Only responsible for ServiceNow request submission, not direct AD group modification
- Idempotent: if user is already in the group, inform status instead of submitting duplicate request
- Do not guarantee approval - approval depends on group sensitivity and approvers
- Sensitive groups (prod-*, admin-*, etc.) require additional business justification and higher-level approval
- Respect user's privacy - do not share applicant information unnecessarily
- Access effective time: typically within 15 minutes after approval

## Error Handling

- **AD group not found**: Inform user that the specified group doesn't exist, suggest verifying the group name or checking the AD group catalog
- **Insufficient permissions**: If user cannot access the request form, inform them about permission requirements
- **Request rejected**: If previous request was rejected, inform user of the rejection reason if available, suggest addressing the issue before resubmitting
- **Duplicate request detected**: Inform user about existing pending request, provide ticket number and status
- **Already member**: If user is already in the group, inform them and provide guidance on how to verify their membership

## Related Skills

- `sn-request-software` - Request software installation in ServiceNow
- `env-configure-path` - Configure environment variables (may be needed after gaining access to certain resources)
