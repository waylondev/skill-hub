---
name: web-fill-sample-form
description: Use this skill when the user wants to practice form filling, test browser automation capabilities, or demonstrate automated form completion on a sample web form. Opens a public demo form page and fills in sample data.
metadata:
  version: 1.0.0
  displayName: Fill Sample Web Form
  domain: web
  action: fill
  object: sample-form
  tags: [web, form, demo, practice, browser]
  type: SKILL
inputs:
  - name: form_url
    type: string
    required: false
    description: URL of the sample form page. Default: https://httpbin.org/forms/post
  - name: full_name
    type: string
    required: false
    description: Full name to fill in the form (default: "John Doe")
  - name: email
    type: string
    required: false
    description: Email address to fill (default: "john.doe@example.com")
  - name: country
    type: string
    required: false
    description: Country to select (default: "United States")
  - name: headed_mode
    type: boolean
    required: false
    description: Whether to run browser in headed mode (visible, default: true)
---
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
- `browser-use` CLI installed (AI will check and suggest installation if needed)

## Execution Steps

AI will use browser-use CLI commands to:
1. Open the form page
2. View available elements and their indices
3. Fill in form fields using element indices
4. Submit the form (if requested)
5. Report the result

Note: AI can use `browser-use --help` to discover available commands and their usage.

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

## Usage Examples

**Example 1: Fill form with custom data (headed mode)**
```yaml
- skill: web-fill-sample-form
  parameters:
    form_url: https://httpbin.org/forms/post
    full_name: "Alice Johnson"
    email: "alice@example.com"
    country: "Canada"
    headed_mode: true
```
AI will execute:
```bash
browser-use open https://httpbin.org/forms/post
browser-use state
browser-use click <name_field_index>
browser-use type "Alice Johnson"
# ... continue filling other fields
```

**Example 2: Fill form with default data (headless mode)**
```yaml
- skill: web-fill-sample-form
  parameters:
    headed_mode: false
```
This will use default values and run in background (no browser window shown).

**Example 3: Fill form for practice (default behavior)**
```yaml
- skill: web-fill-sample-form
```
This will use all default values and open browser in headed mode for learning.

**Example 4: AI discovers and uses CLI automatically**
When AI sees this SKILL, it should:
1. Check if `browser-use` CLI is available: `browser-use --version`
2. If not installed, suggest: `pipx install browser-use`
3. Execute CLI commands directly to fill the form

## Implementation Notes

**Workflow**:
1. Initialize browser automation with headed mode (visible browser)
2. Navigate to sample form page (default: httpbin.org/forms/post)
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
