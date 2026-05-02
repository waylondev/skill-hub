---
name: web-fill-complex-form
description: >-
  Fills complex web forms with dynamic comboboxes, async-loaded options, and search-type dropdowns using agent-browser.
  Invoke when user needs to automate forms where options load after clicking or typing, requiring wait/snapshot/interact patterns.
---

# Fill Complex Web Form with Dynamic Elements

## Purpose

Automate complex web forms that require:
- Clicking combobox/dropdown to load options dynamically
- Typing to trigger async search before selecting options
- Multi-step interactions with wait periods between actions
- Forms with lazy-loaded or conditional fields

## Trigger Conditions

Use this Skill when:
- Form has comboboxes that load options only after clicking
- Dropdown requires typing to trigger search before options appear
- Form fields are conditionally shown based on previous selections
- User needs to practice complex form automation patterns
- Testing browser automation capabilities on dynamic forms

## Prerequisites

- Internet connection is available
- `agent-browser` CLI installed (`npm install -g agent-browser`)
- Target form page is accessible from the network

## Execution Strategy

### Core Pattern: Click → Wait → Snapshot → Select

For dynamic comboboxes and async dropdowns:

```bash
# Step 1: Click the combobox to trigger option loading
agent-browser click @e1

# Step 2: Wait for options to load (choose appropriate wait strategy)
agent-browser wait 1000                      # Fixed wait (simple cases)
agent-browser wait ".option-item"            # Wait for element (preferred)
agent-browser wait --text "Option Name"      # Wait for specific text

# Step 3: Re-snapshot to get fresh refs for loaded options
agent-browser snapshot -i

# Step 4: Select the desired option using new refs
agent-browser click @e3                      # Click the option
```

### Search-Type Dropdown Pattern

For dropdowns that require typing before options appear:

```bash
# Step 1: Click the input field
agent-browser click @e1

# Step 2: Type search query
agent-browser fill @e1 "search term"

# Step 3: Wait for async options to load
agent-browser wait 1500                      # Wait for API response
agent-browser wait ".search-result"          # Wait for result element

# Step 4: Re-snapshot to discover loaded options
agent-browser snapshot -i

# Step 5: Select the desired option
agent-browser click @e4                      # Click matching option
```

### Multi-Step Conditional Form

For forms where fields appear based on previous selections:

```bash
# Fill initial field
agent-browser fill @e1 "value"
agent-browser wait 500
agent-browser snapshot -i

# Read snapshot to discover new fields, then fill them
agent-browser fill @e3 "dependent value"
agent-browser wait 1000
agent-browser snapshot -i

# Continue filling newly revealed fields
agent-browser fill @e5 "next value"
```

## Essential Commands

### Navigation & Snapshot
```bash
agent-browser open <url>              # Navigate to form page
agent-browser snapshot -i             # Get interactive elements with refs
agent-browser snapshot -i --urls      # Include href URLs
```

### Interaction
```bash
agent-browser click @e1               # Click element (combobox, option, etc.)
agent-browser fill @e2 "text"         # Clear input and type
agent-browser type @e2 "text"         # Type without clearing
agent-browser select @e1 "option"     # Select from static dropdown
agent-browser check @e1               # Check checkbox
agent-browser press Enter             # Press key (e.g., to confirm selection)
```

### Wait Strategies
```bash
agent-browser wait 2000               # Wait milliseconds (fixed delay)
agent-browser wait "#selector"        # Wait for element to appear
agent-browser wait --text "Results"   # Wait for text to appear
agent-browser wait --fn "condition"   # Wait for JS condition
agent-browser wait --load networkidle # Wait for network idle (use cautiously)
```

### Batch Execution (Efficiency)
```bash
# Chain commands that don't need intermediate output reading
agent-browser batch "open https://example.com" "snapshot -i"
agent-browser batch "fill @e1 \"value\"" "wait 500" "click @e2"
```

## Workflow

### Standard Complex Form Filling

```bash
# 1. Navigate to form
agent-browser open <form_url>

# 2. Take initial snapshot
agent-browser snapshot -i

# 3. Fill simple fields (no dynamic loading needed)
agent-browser batch "fill @e1 \"John Doe\"" "fill @e2 \"john@example.com\""

# 4. Handle combobox (click to load options)
agent-browser click @e3                # Click combobox
agent-browser wait 1000                # Wait for options to load
agent-browser snapshot -i              # Re-snapshot to get option refs
agent-browser click @e7                # Select desired option

# 5. Handle search-type dropdown (type to trigger search)
agent-browser fill @e4 "search query"  # Type to trigger async load
agent-browser wait 2000                # Wait for API response
agent-browser snapshot -i              # Re-snapshot to get search results
agent-browser click @e12               # Select matching result

# 6. Handle conditional fields
agent-browser snapshot -i              # Check for new fields
# ... fill newly revealed fields ...

# 7. Final verification
agent-browser screenshot output/form.png  # Capture filled form state
```

## Ref Lifecycle (CRITICAL)

**Refs (@e1, @e2, etc.) are invalidated when:**
- Page navigation occurs
- DOM changes significantly (dropdown opens, options load)
- Dynamic content appears/disappears

**Always re-snapshot after:**
- Clicking comboboxes or dropdowns
- Typing in search fields
- Any action that triggers dynamic content loading

```bash
agent-browser click @e3              # Opens dropdown, loads options
agent-browser snapshot -i            # MUST re-snapshot to get new refs
agent-browser click @e8              # Use NEW refs for options
```

## Error Handling

- **Combobox not found**: Inform user, skip field, continue with next field
- **Options not loading after click**: Increase wait time, try alternative wait strategy
- **Search returns no results**: Inform user, try different search term
- **Ref not found after snapshot**: Page structure changed, re-snapshot and retry
- **Form field conditional not triggered**: Previous selection may be incorrect, verify
- **Timeout on wait**: Increase timeout or use different wait strategy
- **Dropdown closes before selection**: Reduce wait time, use batch execution

## Constraints

- **Demo Purpose Only**: Does not submit forms unless explicitly requested
- **Public Forms Only**: Only accesses publicly available demo forms
- **No Real Data**: Uses sample/test data, not real user information
- **Headed Mode Default**: Uses visible browser by default for better UX
- **Idempotent**: Each form fill is independent, no data persistence

## Recommended Test Forms

| Form | URL | Tests |
|------|-----|-------|
| Vuetify Combobox | https://vuetifyjs.com/en/components/combobox/ | Dynamic option loading |
| Material UI Autocomplete | https://mui.com/material-ui/react-autocomplete/ | Async search, virtual scroll |
| Ant Design Select | https://ant.design/components/select | Remote search, multi-select |
| React Select | https://react-select.com/home | Async, creative, grouped |
| Basic Form | https://httpbin.org/forms/post | Baseline form filling |
| DemoQA Practice Form | https://demoqa.com/automation-practice-form | Dynamic City/State combobox |

## Implementation Notes

**Key Principles**:
1. **Always snapshot before and after dynamic actions**
2. **Use appropriate wait strategies for each scenario**
3. **Batch simple commands, separate commands when reading output is needed**
4. **Re-snapshot after any DOM-changing action**
5. **Handle conditional fields by checking for new elements after each selection**

**Performance Tips**:
- Use `batch` for 2+ sequential commands that don't need intermediate output
- Use `snapshot -i` once, extract all info, then batch remaining actions
- Prefer element/text wait over fixed millisecond wait when possible
- Avoid `wait --load networkidle` on pages with persistent network activity

## Python Script Implementation

For stable automation (not relying on LLM), use the Python script:

```bash
python form_filler.py
```

This script:
- Uses agent-browser CLI via subprocess
- Supports TEXT, RADIO, CHECKBOX, COMBOBOX, SEARCH field types
- Configuration-driven: easy to add new fields
- Handles dynamic combobox and async search dropdowns
- Saves screenshots automatically
