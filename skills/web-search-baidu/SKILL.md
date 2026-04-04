---
name: web-search-baidu
description: >-
  Use this skill when the user wants to perform a web search on Baidu and retrieve search results.
version: 1.0.0
displayName: Baidu Web Search
domain: web
action: search
object: baidu
tags: [web, search, baidu, automation, browser]
type: SKILL
inputs:
  - name: query
    type: string
    required: true
    description: Search keyword or phrase to search for on Baidu
  - name: num_results
    type: number
    required: false
    description: Number of search results to return (default: 5)
---
# Baidu Web Search

Perform web searches on Baidu and return readable search results using appropriate automation tools.

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

### Step 2: Choose Appropriate Tool

Based on available tools and environment, select the most appropriate approach:
- **Browser automation** (preferred for interactive tasks)
- **API access** (if available)
- **HTTP client + HTML parsing** (lightweight)
- **Manual browser** (fallback - provide links)

Select based on:
- What's available in the environment
- User's needs (interactive vs. data-only)
- Complexity vs. speed trade-off

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
  - Sponsored results (marked as "广告")
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

- **Single Responsibility**: Only responsible for Baidu search, not other search engines
- **Read-Only Operation**: Does not interact with search results beyond viewing
- **Session Management**: Each search is independent, no session persistence
- **Rate Limiting**: Respect Baidu's terms of service, avoid excessive automated requests
- **No Authentication**: Does not handle logged-in Baidu searches
- **Tool Agnostic**: Does not mandate specific automation tool - AI chooses based on availability
- **Network Dependency**: Requires internet access to Baidu.com
- **Result Accuracy**: Search results may vary based on location, time, and personalization

## Error Handling

- **No automation tool available**: "No web automation tool found. You can install a browser automation tool, or I can guide you to search manually in browser."
- **Network error**: "Cannot connect to Baidu.com. Please check your internet connection and firewall settings."
- **Page load timeout**: "Baidu page failed to load. The website may be temporarily unavailable or blocked."
- **Search query empty**: "Please provide a search query to search for."
- **No results found**: "No search results found for '{{query}}'. Please try different keywords."
- **Results extraction failed**: "Failed to extract search results. The page structure may have changed."
- **Access blocked**: "Access to Baidu.com is blocked or restricted from your network."
- **Tool execution failed**: "The automation tool encountered an error. Trying alternative approach..."
- **Browser open failed**: "Unable to open browser automatically. You can manually open the result at: <result_url>"
- **System command not available**: "System command to open browser is not available on this platform. Please open the link manually."

## Related Skills

- `web-search-google` - Search on Google (if available)
- `web-search-bing` - Search on Bing (if available)
- `web-scrape-page` - Scrape content from a specific webpage

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

## Implementation Notes

**Approach**: Use browser automation to perform search on Baidu and extract results.

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

**Option B: Search API** (If available)

Direct API calls if you have access to a search API:
```
1. Call search API with query
2. Parse JSON response
3. Format and return results
```

**Option C: HTTP Client + HTML Parser** (Lightweight)

Using command-line tools or libraries:
- Use HTTP client to fetch the search results page with the query parameter
- Parse the HTML response to extract search results

**Option D: Manual Browser** (Fallback)

When no automation is available:
```
1. Open browser
2. Navigate to Baidu
3. Guide user through search
4. Help analyze results
```

**Important**: 
- AI should choose appropriate selectors based on the actual page structure
- Focus on locating the search input field, submitting the query, and extracting search results
- Adapt to page structure changes dynamically
- Focus on readable, user-friendly output
- Respect robots.txt and terms of service
- Choose tool based on what's available in the environment
