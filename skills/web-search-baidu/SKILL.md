---
name: web-search-baidu
description: >-
  Use this skill when the user wants to search on Baidu, retrieve search results,
  or find information from Baidu search engine. Supports customizable result count.
version: 1.0.0
displayName: Baidu Search
domain: web
action: search
object: baidu
tags: [web, search, baidu, browser]
type: SKILL
inputs:
  - name: query
    type: string
    required: true
    description: Search query string
  - name: num_results
    type: integer
    required: false
    description: Number of search results to return (default: 10)
  - name: open_browser
    type: boolean
    required: false
    description: Whether to open browser with search results (default: true)
---
# Baidu Web Search

## Purpose

Search on Baidu and retrieve search results only. Does not handle content scraping or detailed analysis.

## Trigger Conditions

Use this Skill when:
- User needs to search for information on Baidu
- User wants to retrieve search results programmatically
- User needs to perform automated web searches
- Research or information gathering is required

## Prerequisites

- Internet connection is available
- Baidu.com is accessible from the network
- Browser automation capability is available (AI will use appropriate tools)

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:
- Verify `query` parameter is provided and not empty
- If `num_results` is provided, ensure it's a positive number (1-20)
- If `num_results` is not provided, default to 5
- If validation fails, inform user with specific error message

### Step 2: Choose Approach

Select the best approach based on environment and user needs:
- **Interactive** (user wants to browse results) → Use browser automation
- **Data-only** (user wants info) → Use API or HTTP client
- **Fallback** → Provide manual links

### Step 3: Navigate to Baidu

Using the chosen tool:
- Open Baidu homepage
- Wait for page to load completely
- Verify page is accessible

### Step 4: Enter Search Query

On Baidu homepage:
- Locate the search input field
- Clear any existing text
- Type the provided `query` parameter

### Step 5: Submit Search and Wait for Results

- Submit the search (click button or press Enter)
- Wait for search results page to load
- Ensure results are fully rendered

### Step 6: Extract Search Results

From the search results page:
- Locate search result containers
- For each result (up to `num_results`):
  - Extract title
  - Extract URL
  - Extract snippet/description
  - Store as structured data
- Handle special cases:
  - Sponsored results (marked as "sponsored" or "ad")
  - Rich results (videos, images)

### Step 7: Format and Return Results

Organize search results:
- Create a readable summary with:
  - Total search query
  - Number of results returned
  - List of results with title, URL, and snippet
- Format in a clear, readable structure
- Include the search URL for reference

### Step 8: Open Result in Browser (If User Selects)

If user selects a specific search result to view:
- **Extract the result URL** from the search results
- **Open the result in user's browser**
- **Keep browser open** for user to view the content
- **Verify page loads successfully**

### Step 9: Clean Up

After completing the task:
- **Do not close browser** - Leave it open for user to view content
- Clean up any temporary resources (if any were created)
- Ensure no background processes left running

### Step 10: Inform User

Present results to user:
- Display formatted search results
- Provide summary statistics
- **Confirm if browser was opened successfully**
- Mention if any errors or limitations encountered

## Constraints

- **Single Responsibility**: Only handles Baidu search (not other search engines)
- **Read-Only**: No login, form submissions, or interactions beyond searching
- **Tool Agnostic**: AI chooses appropriate tools based on availability
- **Respect Terms**: Follow Baidu's terms of service, avoid excessive requests
- **Public Content Only**: Only searches publicly accessible content
- **No Session Persistence**: Each search is independent

## Error Handling

- **No automation tool available**: Inform user no web automation tool found, offer manual searching guidance
- **Network error**: Inform user to check internet connection and firewall settings
- **Page load timeout**: Inform user page failed to load, website may be unavailable
- **Search query empty**: Inform user to provide search query
- **No results found**: Inform user no search results found, suggest different keywords
- **Results extraction failed**: Inform user failed to extract results, page structure may have changed
- **Access blocked**: Inform user access is blocked or restricted from network
- **Tool execution failed**: Inform user automation tool encountered error, try alternative approach
- **Browser open failed**: Inform user unable to open browser automatically, provide link for manual opening
- **System command not available**: Inform user system command not available on platform

## Example Usage

**Example 1: Basic Search**
```
User: "Search for 'Python tutorial' on Baidu"
AI: Uses web-search-baidu with query="Python tutorial"
Result: Returns top 5 search results with titles, URLs, and snippets
```

**Example 2: Custom Result Count**
```
User: "Find information about machine learning, show me 10 results"
AI: Uses web-search-baidu with query="machine learning", num_results=10
Result: Returns top 10 search results
```

**Example 3: Research Task**
```
User: "I need to research React hooks best practices"
AI: Uses web-search-baidu with query="React hooks best practices"
Result: Returns relevant articles and documentation links
```

**Example 4: Open Search Result**
```
User: "Search for AI tutorial and open the first result"
AI: Uses web-search-baidu to search, then opens browser with first result
Result: Opens the top search result URL in user's default browser
```

**Example 5: Interactive Search**
```
User: "Search for Python tutorials"
AI: Shows search results with numbered list
User: "Open result 2"
AI: Opens the 2nd search result URL in browser automatically
Result: Browser launches and displays the selected webpage
```

**Example 6: Fallback When Automation Unavailable**
```
User: "Search for JavaScript guide"
AI: Browser automation not available, provides search URL and manual links
Result: User can click links to browse manually
```

## Implementation Notes

**Workflow**:
1. Navigate to Baidu homepage
2. Enter search query and submit
3. Extract search results (title, URL, snippet)
4. Present results to user in a clear format
5. If user selects a result, open it in their browser
6. Keep browser open for user to view

**Key Points**:
- Focus on user experience (show browser, don't close automatically)
- Extract meaningful information (not just URLs)
- Handle errors gracefully
- Respect website terms of service
