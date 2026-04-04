---
name: web-bilibili-trending
description: >-
  Use this skill when the user wants to browse Bilibili trending videos and retrieve popular content.
version: 1.0.0
displayName: Bilibili Trending Videos
domain: web
action: browse
object: bilibili
tags: [web, bilibili, trending, videos, automation, browser]
type: SKILL
inputs:
  - name: category
    type: string
    required: false
    description: Video category to filter trending videos (e.g., animation, music, dance, game, etc.)
  - name: time_range
    type: string
    required: false
    description: Time range for trending videos - 'today', '3days', 'week' (default: 'today')
  - name: num_results
    type: number
    required: false
    description: Number of trending videos to retrieve (default: 10, range: 1-50)
---
# Bilibili Trending Videos

Browse Bilibili trending videos page and retrieve popular video information using appropriate automation tools.

## Trigger Conditions

Use this Skill when:
- User wants to see what's popular on Bilibili
- User needs to browse trending videos by category
- User wants to discover new content on Bilibili
- Research or content analysis is required

## Prerequisites

- Internet connection is available
- Bilibili.com is accessible from the network
- Browser or web automation tool is available (Playwright, Puppeteer, Selenium, etc.)
- Or Bilibili API access is available (optional)

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:
- Verify `category` parameter if provided (check against valid Bilibili categories)
- If `time_range` is provided, ensure it's one of: 'today', '3days', 'week'
- If `time_range` is not provided, default to 'today'
- If `num_results` is provided, ensure it's between 1-50
- If `num_results` is not provided, default to 10
- If validation fails, inform user with specific error message

### Step 2: Choose Appropriate Tool

Based on available tools and environment, select one:

- **Option A: Browser Automation** (if available) - Playwright, Puppeteer, Selenium, etc.
- **Option B: Bilibili API** (if available) - Direct API calls to Bilibili open platform
- **Option C: HTTP Client + HTML Parser** (lightweight) - curl/wget + cheerio/jsoup
- **Option D: Manual Browser** (fallback) - Open browser and guide user

Select the most appropriate tool based on:
- What's installed and available
- User's environment and preferences
- Complexity vs. speed trade-off

### Step 3: Navigate to Bilibili Trending Page

Using the chosen tool:
- Open Bilibili homepage
- Navigate to the trending/ranking page
- Wait for page to load completely
- Verify page is accessible and shows trending content

### Step 4: Apply Filters (If Specified)

If `category` parameter is provided:
- Locate category filter on the page
- Select the specified category
- Wait for page to refresh with filtered results

If `time_range` parameter is provided:
- Locate time range filter (today/3days/week)
- Select the specified time range
- Wait for page to update with filtered results

### Step 5: Extract Trending Videos

From the trending page:
- Locate video list container
- For each video (up to `num_results`):
  - Extract video title
  - Extract video URL
  - Extract thumbnail URL
  - Extract view count
  - Extract like count (danmaku/likes)
  - Extract uploader/channel name
  - Extract video duration
  - Extract ranking position
  - Store as structured data
- Handle special cases:
  - Sponsored/promoted videos
  - New uploads vs established trending
  - Different video formats (vertical, horizontal)

### Step 6: Format and Return Results

Organize trending videos:
- Create a readable summary with:
  - Category (if filtered)
  - Time range
  - Number of videos returned
  - List of videos with title, URL, views, uploader
- Format in a clear, readable structure
- Include the trending page URL for reference
- Optionally include thumbnail images if supported

### Step 7: Clean Up

After extracting results:
- Close browser if opened
- Clean up any temporary resources
- Ensure no processes left running

### Step 8: Inform User

Present results to user:
- Display formatted trending videos list
- Provide summary statistics (total views, top category, etc.)
- Offer to open any specific video URL
- Mention if any errors or limitations encountered
- Suggest related categories if user wants to explore more

## Constraints

- **Single Responsibility**: Only responsible for Bilibili trending videos, not other pages or search
- **Read-Only Operation**: Does not interact with videos beyond viewing (no login, no comments)
- **Session Management**: Each browse is independent, no session persistence
- **Rate Limiting**: Respect Bilibili's terms of service, avoid excessive automated requests
- **No Authentication**: Does not handle logged-in Bilibili browsing
- **Tool Agnostic**: Does not mandate specific automation tool - AI chooses based on availability
- **Network Dependency**: Requires internet access to Bilibili.com
- **Content Accuracy**: Trending content may vary based on region, time, and personalization
- **Public Content Only**: Only accesses publicly available trending videos

## Error Handling

- **No automation tool available**: "No web automation tool found. You can install a browser automation tool, or I can guide you to browse manually in browser."
- **Network error**: "Cannot connect to Bilibili.com. Please check your internet connection and firewall settings."
- **Page load timeout**: "Bilibili page failed to load. The website may be temporarily unavailable or blocked."
- **Invalid category**: "The category '{{category}}' is not valid. Available categories: animation, music, dance, game, technology, life, fashion, entertainment, etc."
- **No trending videos found**: "No trending videos found. The page structure may have changed or Bilibili may be experiencing issues."
- **Results extraction failed**: "Failed to extract trending videos. The page structure may have changed."
- **Access blocked**: "Access to Bilibili.com is blocked or restricted from your network."
- **Tool execution failed**: "The automation tool encountered an error. Trying alternative approach..."
- **Region restriction**: "Bilibili trending may not be available in your region. Consider using a different region setting."

## Related Skills

- `web-search-baidu` - Search for specific content on Baidu
- `web-browse-page` - Browse any specific webpage (if user has a specific URL)
- `web-scrape-page` - Scrape detailed content from a specific video page

## Example Usage

**Example 1: Basic Trending**
```
User: "Show me what's trending on Bilibili"
AI: Uses web-bilibili-trending with default parameters
Result: Returns top 10 trending videos for today
```

**Example 2: Category Filter**
```
User: "What's popular in the animation category on Bilibili?"
AI: Uses web-bilibili-trending with category="animation"
Result: Returns top 10 trending animation videos
```

**Example 3: Custom Time Range**
```
User: "Show me this week's trending videos on Bilibili, top 20"
AI: Uses web-bilibili-trending with time_range="week", num_results=20
Result: Returns top 20 trending videos for the week
```

**Example 4: Content Discovery**
```
User: "I want to discover new content on Bilibili"
AI: Uses web-bilibili-trending to show trending videos
Result: Returns diverse trending content across categories
```

## Implementation Notes

**Tool Options** (AI should choose based on availability):

**Option A: Browser Automation** (Recommended if available)

Any browser automation library such as:
- Playwright (Node.js, Python, .NET, Java)
- Puppeteer (Node.js)
- Selenium (Multi-language)

Example workflow:
```
1. Launch browser
2. Navigate to Bilibili trending page
3. Apply category/time filters if specified
4. Wait for content to load
5. Extract video information
6. Format and return results
```

**Option B: Bilibili API** (If available)

Direct API calls if you have access to Bilibili open platform:
```
1. Call Bilibili ranking API
2. Pass category and time range parameters
3. Parse JSON response
4. Format and return results
```

**Option C: HTTP Client + HTML Parser** (Lightweight)

Using command-line tools or libraries:
- Use HTTP client to fetch the trending page
- Parse the HTML response to extract video information

**Option D: Manual Browser** (Fallback)

When no automation is available:
```
1. Open browser
2. Navigate to Bilibili trending page
3. Guide user through browsing
4. Help analyze trending content
```

**Important**: 
- AI should choose appropriate selectors based on the actual page structure
- Focus on locating the trending video list container and extracting video information
- Adapt to page structure changes dynamically
- Focus on readable, user-friendly output
- Respect robots.txt and terms of service
- Choose tool based on what's available in the environment
- Bilibili may have anti-scraping measures - use appropriate delays
- Consider rate limiting to avoid IP blocking
