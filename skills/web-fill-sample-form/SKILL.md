***

name: web-fill-sample-form
description: >-
Use this skill when the user wants to practice form filling,
test browser automation capabilities, or demonstrate automated
form completion on a sample web form. Opens a public demo form page
and fills in sample data.
version: 1.0.0
displayName: Fill Sample Web Form
domain: web
action: fill
object: sample-form
tags: \[web, form, demo, practice, browser]
type: SKILL
inputs:

name: form\_url
type: string
required: false
description: >-
  URL of the sample form page.
  Default: https://httpbin.org/forms/post

- name: full\_name
  type: string
  required: false
  description: Full name to fill in the form (default: "John Doe")
- name: email
  type: string
  required: false
  description: Email address to fill (default: "<john.doe@example.com>")
- name: country
  type: string
  required: false
  description: Country to select (default: "United States")
- name: headed\_mode
  type: boolean
  required: false
  description: Whether to run browser in headed mode (visible, default: true)

***

# Fill Sample Web Form

## Purpose

Open a public demo form page and fill in sample data for practice or testing purposes. Does not submit the form or handle real data.

## Trigger Conditions

Use this Skill when:

- User wants to practice browser automation on a sample form
- User wants to test form filling capabilities
- User needs to demonstrate automated form completion
- User wants to verify browser automation is working correctly
- User needs a safe environment to test form automation

## Prerequisites

- Internet connection is available
- Target form page is accessible from the network
- Python environment is installed and available
- Browser automation capability is available (AI will use appropriate tools)

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:

- Verify `form_url` parameter or use default demo URL
- If `full_name` is not provided, default to "John Doe"
- If `email` is not provided, default to "<john.doe@example.com>"
- If `country` is not provided, default to "United States"
- If `headed_mode` is not provided, default to true (visible browser)
- Validate email format if provided
- If validation fails, inform user with specific error message

### Step 2: Initialize Browser Automation

Set up browser-use with appropriate configuration:

- Use headed mode if `headed_mode` is true (shows browser window)
- Use headless mode if `headed_mode` is false (background execution)
- Ensure browser is properly initialized
- Verify browser automation is ready

### Step 3: Navigate to Sample Form Page

Using browser automation:

- Open the target form URL in browser
- Wait for page to load completely
- Verify form page is accessible and shows form elements
- Handle any popups or cookie consent dialogs if they appear
- If page fails to load, inform user and stop

### Step 4: Locate Form Container

On the form page:

- Find the main form element (typically `<form>` tag)
- Identify form container or section
- Verify form is visible and interactive
- Ensure all form fields are accessible

### Step 5: Fill in Full Name Field

Locate and fill the name field:

- Find the full name input field (look for labels like "Name", "Full Name", "Your Name")
- Clear any existing text in the field
- Enter the `full_name` parameter value
- Ensure text is fully entered and visible
- Verify the field contains the correct value

### Step 6: Fill in Email Field

Locate and fill the email field:

- Find the email input field (look for labels like "Email", "E-mail", "Email Address")
- Clear any existing text in the field
- Enter the `email` parameter value
- Ensure text is fully entered and visible
- Verify the field contains the correct value

### Step 7: Select Country from Dropdown

If country dropdown exists:

- Find the country selection dropdown (look for labels like "Country", "Select Country")
- Click to open the dropdown menu
- Find and select the `country` option
- Verify the correct country is selected
- If country not found, select the first available option

### Step 8: Fill Additional Fields (If Present)

If the form has additional common fields:

- **Phone**: Fill with sample phone number "+1-555-0123"
- **Message/Comments**: Fill with sample text "This is a test message"
- **Subject**: Fill with "Test Subject"
- **Checkboxes**: Check the first available checkbox if appropriate
- **Radio Buttons**: Select the first option if appropriate
- Only fill fields that are clearly visible and safe to modify

### Step 9: Review Filled Form

Before submission (but do not submit):

- Verify all filled fields contain correct values
- Check that name field contains the full name
- Check that email field contains the email address
- Check that country dropdown shows the selected country
- Ensure no error messages are displayed
- Confirm form looks complete and valid

### Step 10: Do NOT Submit Form

**Important**:

- **Do not click submit button** - This is a demo/practice form
- **Do not send real data** - Sample data should not be submitted
- **Keep form filled** - Leave the form filled for user to review
- **Inform user** - Tell user form is filled but not submitted

### Step 11: Keep Browser Open for User

After successful form filling:

- **Do not close browser** - Leave it open for user to review
- **Keep form visible** - Allow user to see filled data
- Inform user that browser is ready for viewing
- Provide summary of filled fields

### Step 12: Inform User

Present results to user:

- Confirm form is filled successfully
- Display filled information:
  - Full name filled
  - Email filled
  - Country selected
  - Any additional fields filled
- Mention that form was NOT submitted (demo only)
- Mention that browser is in headed mode (visible)
- Offer to fill other forms or submit if user confirms

## Constraints

- **Single Responsibility**: Only fills sample/demo forms, does not handle real production forms
- **Idempotent**: Each form fill is independent, no data persistence
- **Tool Agnostic**: AI chooses appropriate browser automation tools based on availability
- **Demo Purpose Only**: Does not submit forms or send real data
- **Public Forms Only**: Only accesses publicly available demo forms
- **No Real Data**: Uses sample/test data, not real user information
- **Headed Mode Default**: Uses visible browser by default for better user experience
- **Do Not Submit**: Fills form but does not click submit button unless explicitly requested

## Error Handling

- **Python not installed**: Inform user Python environment not found, provide installation instructions
- **Browser automation not available**: Inform user no browser automation tool found, provide manual form URL
- **Network error**: Inform user to check internet connection and firewall settings
- **Form page load timeout**: Inform user form page may be unavailable or blocked
- **Form not found**: Inform user cannot locate form on the page, page structure may have changed
- **Field not found**: Skip missing fields, inform user which fields could not be filled
- **Country not in list**: Inform user selected country not available, use first available option
- **Form already filled**: Inform user form appears to have data, offer to clear and refill
- **Browser automation failed**: Inform user browser automation encountered error, try alternative approach
- **Access blocked**: Inform user access to form page is blocked or restricted from network
- **Headed mode not supported**: If headed mode fails (e.g., no display), inform user and suggest headless mode
- **Invalid email format**: Inform user email format is invalid, use default sample email
- **Page structure changed**: Inform user page layout may have changed, form filling may be incomplete

## Example Usage

**Example 1: Basic Form Fill**

```
User: "Fill out a sample form for practice"
AI: Uses web-fill-sample-form with default values
Result: Opens browser, navigates to demo form, fills with default data
```

**Example 2: Custom Data**

```
User: "Fill a form with name Alice and email alice@test.com"
AI: Uses web-fill-sample-form with full_name="Alice", email="alice@test.com"
Result: Opens browser, fills form with custom data
```

**Example 3: Headless Mode**

```
User: "Fill a form in background for testing"
AI: Uses web-fill-sample-form with headed_mode=false
Result: Runs browser in headless mode, fills form without showing UI
```

**Example 4: Specific Form URL**

```
User: "Fill the form at this URL: https://example.com/contact"
AI: Uses web-fill-sample-form with form_url="https://example.com/contact"
Result: Opens specified URL and fills the form
```

**Example 5: Fallback When Automation Unavailable**

```
User: "Fill out a practice form"
AI: Browser automation not available, provides manual form URL
Result: User can click link to fill form manually
```

## Implementation Notes

**Workflow**:

1. Initialize browser-use with headed mode (visible browser)
2. Navigate to sample form page (default: w3docs.com demo)
3. Locate form container and fields
4. Fill in name, email, country fields
5. Fill additional fields if present
6. Review filled form (do not submit)
7. Keep browser open for user to review
8. Provide summary of filled fields

**Key Points**:

- Use headed mode by default (better user experience)
- Focus on user experience (show browser, don't close automatically)
- Use sample/test data only (no real user information)
- Do NOT submit the form (demo purpose only)
- Handle errors gracefully
- Skip fields that cannot be found

**Recommended Tool**:
- AI will choose appropriate browser automation tools based on availability
- Examples: browser-use, Playwright, Puppeteer, Selenium, or other suitable tools
- Tool selection is based on environment capabilities and task requirements

**Default Form URL**:
- https://httpbin.org/forms/post
- This is a public, free-to-use demo form page
- Contains standard form fields for testing
- Safe for practice (does not store submitted data)

**Sample Data**:
- Name: "John Doe"
- Email: "john.doe@example.com"
- Country: "United States"
- Phone: "+1-555-0123" (if field exists)
- Message: "This is a test message" (if field exists)

