# PowerShell script to generate registry.yaml and registry.lst
$ErrorActionPreference = "Stop"

function Parse-SkillFrontmatter {
    param([string]$SkillPath)
    try {
        $content = Get-Content $SkillPath -Raw -Encoding UTF8
        if ($content -match '^---\s*\n(?s)(.*?)\n---\s*\n') {
            $frontmatterYaml = $matches[1]
            $frontmatter = @{}
            $inMultiline = $false
            $currentKey = ""
            $multilineValue = @()
            
            foreach ($line in $frontmatterYaml -split "`n") {
                $lineTrimmed = $line.Trim()
                if ($lineTrimmed -eq '' -or $lineTrimmed.StartsWith('#')) {
                    continue
                }
                
                if ($inMultiline) {
                    if ($line -match '^\s{2,}') {
                        $multilineValue += $lineTrimmed
                    } else {
                        if ($currentKey) {
                            $frontmatter[$currentKey] = $multilineValue -join " "
                        }
                        $inMultiline = $false
                    }
                }
                
                if (-not $inMultiline) {
                    if ($line -match '^\s*([a-zA-Z0-9_-]+)\s*:\s*(>\-?|\|)?\s*$') {
                        $currentKey = $matches[1]
                        if ($matches[2]) {
                            $inMultiline = $true
                            $multilineValue = @()
                        }
                    } elseif ($line -match '^\s*([a-zA-Z0-9_-]+)\s*:\s*(.*?)\s*$') {
                        $key = $matches[1]
                        $value = $matches[2]
                        if ($value -match '^\[(.*)\]$') {
                            $value = ($matches[1] -split ',\s*') | ForEach-Object { $_ -replace '^["'']|["'']$', '' }
                        }
                        $frontmatter[$key] = $value
                    }
                }
            }
            
            if ($inMultiline -and $currentKey) {
                $frontmatter[$currentKey] = $multilineValue -join " "
            }
            
            return $frontmatter
        }
    } catch {
        Write-Host "Error parsing $SkillPath : $_"
    }
    return @{}
}

function Generate-Registry {
    $skillsDir = "skills"
    $registry = @{
        version = "1.0"
        updated = Get-Date -Format "yyyy-MM-dd"
        skills = @()
    }
    
    if (-not (Test-Path $skillsDir)) {
        Write-Host "Directory $skillsDir not found"
        return
    }
    
    foreach ($skillDir in Get-ChildItem -Directory $skillsDir) {
        $skillMd = Join-Path $skillDir.FullName "SKILL.md"
        if (-not (Test-Path $skillMd)) {
            continue
        }
        
        $frontmatter = Parse-SkillFrontmatter $skillMd
        if (-not $frontmatter) {
            continue
        }
        
        $skillEntry = @{
            name = if ($frontmatter["name"]) { $frontmatter["name"] } else { $skillDir.Name }
            path = "$skillsDir/$($skillDir.Name)"
            version = if ($frontmatter["version"]) { $frontmatter["version"] } else { "1.0.0" }
            title = if ($frontmatter["displayName"]) { $frontmatter["displayName"] } else { $skillDir.Name }
            domain = if ($frontmatter["domain"]) { $frontmatter["domain"] } else { "" }
            tags = if ($frontmatter["tags"]) { $frontmatter["tags"] } else { @() }
        }
        $registry.skills += $skillEntry
    }
    
    $yamlContent = @"
version: "$($registry.version)"
updated: "$($registry.updated)"
skills:
"@
    foreach ($skill in $registry.skills) {
        $tagsYaml = if ($skill.tags.Count -gt 0) { "[" + ($skill.tags -join ", ") + "]" } else { "[]" }
        $yamlContent += @"

  - name: $($skill.name)
    path: $($skill.path)
    version: $($skill.version)
    title: $($skill.title)
    domain: $($skill.domain)
    tags: $tagsYaml
"@
    }
    
    Set-Content -Path "registry.yaml" -Value $yamlContent -Encoding UTF8
    
    $lstContent = ""
    foreach ($skill in $registry.skills) {
        $tagsStr = $skill.tags -join ","
        $lstContent += "$($skill.name)|$($skill.path)|$($skill.version)|$($skill.title)|$($skill.domain)|$tagsStr`n"
    }
    
    Set-Content -Path "registry.lst" -Value $lstContent.TrimEnd() -Encoding UTF8
    
    Write-Host "Generated registry.yaml with $($registry.skills.Count) skills"
    Write-Host "Generated registry.lst with $($registry.skills.Count) skills"
}

Generate-Registry
