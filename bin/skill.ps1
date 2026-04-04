# Skill-Hub CLI - PowerShell Version
# Turn Confluence theoretical knowledge into AI execution capabilities

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(Position=1)]
    [string]$Arg1
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SkillsDir = Join-Path $RepoRoot "skills"
$RegistryLstPath = Join-Path $RepoRoot "registry.lst"
$HomeDir = if ($IsWindows) { $env:USERPROFILE } else { $env:HOME }
$LocalSkillHubDir = Join-Path $HomeDir ".skillhub"
$LocalSkillsDir = Join-Path $LocalSkillHubDir "skills"

function Show-Help {
    Write-Host "Skill-Hub CLI - Turn Confluence theoretical knowledge into AI execution capabilities"
    Write-Host ""
    Write-Host "Usage: skill command [args]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  search keyword   - Search for Skills"
    Write-Host "  install name    - Install Skill locally"
    Write-Host "  uninstall name  - Uninstall local Skill"
    Write-Host "  run name        - Execute Skill"
    Write-Host "  list            - List all Skills"
    Write-Host "  help            - Show help"
    Write-Host ""
}

function Load-Registry {
    if (-not (Test-Path $RegistryLstPath)) {
        Write-Host "Error: registry.lst not found at $RegistryLstPath" -ForegroundColor Red
        $scriptPath = Join-Path $RepoRoot "scripts\generate_registry.ps1"
        if (Test-Path $scriptPath) {
            Write-Host "Please run: .\scripts\generate_registry.ps1" -ForegroundColor Yellow
        } else {
            Write-Host "Warning: generate_registry.ps1 script not found" -ForegroundColor Yellow
        }
        exit 1
    }

    $skills = @()
    $lines = Get-Content $RegistryLstPath -Encoding UTF8
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++
        $line = $line.Trim()
        if ([string]::IsNullOrEmpty($line)) {
            continue
        }

        $parts = $line -split '\|', 6

        if ($parts.Count -lt 2) {
            Write-Host "Warning: Invalid entry at line $lineNumber has fewer than 2 fields, skipping" -ForegroundColor Yellow
            continue
        }

        $name = $parts[0].Trim()
        $path = $parts[1].Trim()

        if ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($path)) {
            Write-Host "Warning: Invalid entry at line $lineNumber has empty name or path, skipping" -ForegroundColor Yellow
            continue
        }

        $version = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
        $title = if ($parts.Count -ge 4 -and -not [string]::IsNullOrEmpty($parts[3])) { $parts[3].Trim() } else { $name }
        $domain = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "" }
        $tagsStr = if ($parts.Count -ge 6) { $parts[5].Trim() } else { "" }

        $tags = @()
        if (-not [string]::IsNullOrEmpty($tagsStr)) {
            $tags = $tagsStr -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrEmpty($_) }
        }

        $skills += @{
            Name = $name
            Path = $path
            Version = $version
            Title = $title
            Domain = $domain
            Tags = $tags
        }
    }

    if ($skills.Count -eq 0) {
        Write-Host "Warning: No valid skills found in registry.lst" -ForegroundColor Yellow
    }

    return $skills
}

function Search-Skill {
    param([string]$Keyword)
    $skills = Load-Registry
    $results = @()

    foreach ($skill in $skills) {
        $match = $false
        if ([string]::IsNullOrEmpty($Keyword)) {
            $match = $true
        } else {
            $kw = $Keyword.ToLower()
            $nameMatch = $skill.Name.ToLower().Contains($kw)
            $titleMatch = $skill.Title.ToLower().Contains($kw)
            $tagMatch = ($skill.Tags -join " ").ToLower().Contains($kw)
            if ($nameMatch -or $titleMatch -or $tagMatch) {
                $match = $true
            }
        }
        if ($match) { $results += $skill }
    }

    if ($results.Count -eq 0) {
        Write-Host "No skills found" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host ("{0,-30} {1,-40} {2,-10} {3,-10}" -f "NAME", "TITLE", "DOMAIN", "VERSION")
    Write-Host ("-" * 95)
    foreach ($skill in $results) {
        Write-Host ("{0,-30} {1,-40} {2,-10} {3,-10}" -f $skill.Name, $skill.Title, $skill.Domain, $skill.Version)
    }
    Write-Host ""
    Write-Host "Found $($results.Count) skill(s)" -ForegroundColor Green
}

function Install-Skill {
    param([string]$Name)
    $skills = Load-Registry
    $skill = $skills | Where-Object { $_.Name -eq $Name }

    if (-not $skill) {
        Write-Host "Skill '$Name' not found" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $LocalSkillsDir)) {
        New-Item -ItemType Directory -Path $LocalSkillsDir -Force | Out-Null
    }

    $destDir = Join-Path $LocalSkillsDir $Name
    $srcSkillMd = Join-Path $RepoRoot $skill.Path "SKILL.md"
    $destSkillMd = Join-Path $destDir "SKILL.md"

    if (-not (Test-Path $srcSkillMd)) {
        Write-Host "Error: SKILL.md not found at $srcSkillMd" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $destDir) {
        Write-Host "Skill '$Name' is already installed at $destDir" -ForegroundColor Yellow
        $overwrite = Read-Host "Overwrite? (y/N)"
        if ($overwrite -ne "y" -and $overwrite -ne "Y") {
            Write-Host "Installation cancelled"
            return
        }
        Remove-Item -Path $destDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -Path $srcSkillMd -Destination $destSkillMd -Force

    Write-Host "Skill '$Name' installed successfully to $destDir" -ForegroundColor Green
}

function Uninstall-Skill {
    param([string]$Name)
    $destDir = Join-Path $LocalSkillsDir $Name

    if (-not (Test-Path $destDir)) {
        Write-Host "Skill '$Name' is not installed" -ForegroundColor Red
        exit 1
    }

    Remove-Item -Path $destDir -Recurse -Force
    Write-Host "Skill '$Name' uninstalled successfully" -ForegroundColor Green
}

function List-Skills {
    Search-Skill
}

function Run-Skill {
    param([string]$Name)

    $destDir = Join-Path $LocalSkillsDir $Name
    $skillMd = Join-Path $destDir "SKILL.md"

    if (-not (Test-Path $destDir)) {
        Write-Host "Skill '$Name' is not installed at $destDir" -ForegroundColor Red
        Write-Host "Please install it first: skill install $Name" -ForegroundColor Yellow
        exit 1
    }

    if (-not (Test-Path $skillMd)) {
        Write-Host "Error: SKILL.md not found at $skillMd" -ForegroundColor Red
        exit 1
    }

    Write-Host "=== Skill: $Name ===" -ForegroundColor Cyan
    Write-Host ""

    $content = Get-Content $skillMd -Raw -Encoding UTF8
    Write-Host $content
}

switch ($Command) {
    "search" { Search-Skill -Keyword $Arg1 }
    "install" { Install-Skill -Name $Arg1 }
    "uninstall" { Uninstall-Skill -Name $Arg1 }
    "run" { Run-Skill -Name $Arg1 }
    "list" { List-Skills }
    "help" { Show-Help }
    default { Show-Help }
}
