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

Collect required information from user:
- **AD group name** (required): Exact name of the AD group to request access to
- **Applicant** (required): User's name or employee ID who needs access
- **Business reason** (required): Why the access is needed
- **Additional justification** (optional): Extra justification for sensitive groups (prod-*, admin-*, etc.)

### Step 2: Check Existing Membership and Requests

Before submitting new request:
- Check if user is already a member of the AD group
  - If already member, inform user: "You are already a member of this AD group. No request needed."
  - Stop and do not proceed
- Check if there's a pending request for the same group by the same applicant
  - If pending request exists, inform user of the status and ticket number
  - Stop and do not proceed
- Check if there's an approved request that hasn't been activated yet
  - If approved request exists, inform user to wait for access activation (typically 15 minutes)
  - Stop and do not proceed

### Step 3: Navigate to ServiceNow AD Group Request Page

- Open the company ServiceNow portal in browser
- Navigate to the AD group request catalog item
  - This is typically a specific URL or link like: `https://servicenow.company.com/?id=ad_group_request`
  - Or navigate through: Service Catalog → Access Requests → AD Group Access
- Ensure user is authenticated with company credentials

### Step 4: Fill in the Request Form

Complete the form fields with collected information:
- **Group Name/Selector**: Enter or select the AD group name provided by user
  - Some forms may have a search/lookup field to find the group
  - User must provide the exact group name
- **Applicant**: Enter the applicant's name or employee ID
- **Business Reason**: Enter the business justification in the text field
- **Additional Justification**: If sensitive group, enter additional details
- Review all fields for accuracy

### Step 5: Submit the Request

- Click the **Submit** or **Request** button
- Wait for confirmation that request was submitted successfully
- Note the request/ticket number displayed (e.g., REQ0012345 or RITM0012345)
- Optionally take a screenshot or save the confirmation page

### Step 6: Inform User

After successful submission:
- Confirm the request was submitted successfully
- Provide the request/ticket number for tracking
- Explain the approval workflow:
  - Standard groups: Department Manager approval
  - Sensitive groups (prod-*, admin-*): Additional IT Security Team approval required
- Give estimated approval timeline:
  - Standard: 1-2 business days
  - Sensitive: 3-5 business days
- Inform user that:
  - Email notification will be sent upon approval
  - Access will be effective within 15 minutes after approval
  - They can check request status using the ticket number

## Constraints

- **Single Responsibility**: Only responsible for ServiceNow web form submission, not direct AD group modification
- **Web-Based Operation**: Requires browser interaction with ServiceNow portal
- **User-Provided Group Name**: AD group name must be provided by user - skill does not auto-select or guess
- **Idempotent**: If user is already member or has pending/approved request, inform status instead of submitting duplicate
- **No Approval Guarantee**: Approval depends on company policies, group sensitivity, and approvers
- **Sensitive Groups**: Groups with patterns like prod-*, admin-*, security-* require additional justification and higher-level approval
- **Privacy**: Do not share applicant information unnecessarily
- **Access Activation Time**: Typically 15 minutes after approval (automated provisioning)

## Error Handling

- **AD Group Not Found**: "The AD group '{{group_name}}' was not found in the directory. Please verify the group name or check the AD group catalog."
- **User Already Member**: "You are already a member of the AD group '{{group_name}}'. No request needed."
- **Pending Request Exists**: "A pending request already exists for this AD group (Ticket: {{ticket_number}}). Status: {{status}}. Please wait for approval."
- **Approved Request Not Activated**: "Your request was approved (Ticket: {{ticket_number}}). Access will be activated within 15 minutes."
- **Insufficient Permissions**: "You don't have permission to access the AD group request form. Please contact your IT admin or manager for access."
- **Request Rejected**: "Your previous request was rejected. Reason: {{rejection_reason}}. Please address the issue before resubmitting."
- **ServiceNow Unavailable**: "Cannot access ServiceNow portal. Please check your network connection and try again."
- **Form Submission Failed**: "Failed to submit the request. Please verify all required fields are filled correctly and try again."
- **Missing Required Information**: "Missing required information: {{field_name}}. Please provide {{field_name}} to proceed."

## Related Skills

- `sn-request-software` - Request software installation in ServiceNow
- `env-configure-path` - Configure environment variables (may be needed after gaining access to certain resources)
