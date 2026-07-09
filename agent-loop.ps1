param(
    [string]$TaskFile   = "tasks.txt",
    [int]   $MaxRetries = 3,
    [int]   $MaxTurns   = 30,
    [float] $MaxCost    = 5.00,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
    exit 1
}
if (-not $env:ANTHROPIC_API_KEY) {
    Write-Error "ANTHROPIC_API_KEY not set."
    exit 1
}
if (-not (Test-Path $TaskFile)) {
    Write-Error "Task file not found: $TaskFile"
    exit 1
}
if (-not (Get-Command selene -ErrorAction SilentlyContinue)) {
    Write-Error "selene not found. Run: aftman install"
    exit 1
}

$tasks = Get-Content $TaskFile |
    Where-Object { $_.Trim() -ne "" -and -not $_.TrimStart().StartsWith("#") }

if ($tasks.Count -eq 0) {
    Write-Host "No tasks found in $TaskFile" -ForegroundColor Yellow
    exit 0
}

$total  = $tasks.Count
$passed = 0
$failed = 0

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "  Agent Loop -- $total task(s)"      -ForegroundColor Cyan
Write-Host "  Max cost: `$$MaxCost"              -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  DRY RUN -- no changes will be made" -ForegroundColor Yellow
}
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-AgentClaude {
    param(
        [string]$Prompt,
        [int]   $Turns   = $MaxTurns,
        [string]$BaseUrl = ""
    )

    if ($DryRun) {
        $preview = $Prompt.Substring(0, [Math]::Min(80, $Prompt.Length))
        Write-Host "    [DRY RUN] $preview..." -ForegroundColor DarkGray
        return @{ Success = $true; Output = "[dry run]" }
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $Prompt -Encoding UTF8

    $savedBase = $env:ANTHROPIC_BASE_URL
    if ($BaseUrl -ne "") { $env:ANTHROPIC_BASE_URL = $BaseUrl }

    try {
        $output = Get-Content $tmp | claude --print --max-turns $Turns --dangerously-skip-permissions --output-format text 2>&1
        $ok     = ($LASTEXITCODE -eq 0)
    } finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        if ($BaseUrl -ne "") { $env:ANTHROPIC_BASE_URL = $savedBase }
    }

    return @{ Success = $ok; Output = ($output -join "`n") }
}

function Invoke-Selene {
    $output = selene src/ 2>&1
    return @{ Success = ($LASTEXITCODE -eq 0); Output = ($output -join "`n") }
}

function Write-Step { param([string]$Text); Write-Host "  $Text" -NoNewline -ForegroundColor Gray }
function Write-OK   { Write-Host " OK"   -ForegroundColor Green }
function Write-Fail { Write-Host " FAIL" -ForegroundColor Red   }

foreach ($rawTask in $tasks) {
    $task = $rawTask.Trim()
    Write-Host "+- $task" -ForegroundColor Yellow
    Write-Host "|"

    # Step 1: Implement
    Write-Step "Implementing"

    $implPrompt = @"
Read CLAUDE.md first (it is at the project root).

Task: $task

Requirements -- follow every rule in CLAUDE.md:
- Read Components.lua and Tags.lua before writing anything
- Use the exact system template from CLAUDE.md
- Never use world:has() inside a system body -- put checks in the query
- Never have a system remove state owned by another system
- Cache all queries outside the system function
- Use bit32.band/bor/bnot -- never use the & | ~ operators
- Run selene src/ after writing each file and fix all errors immediately
- Only finish when selene src/ exits with no errors
"@

    $impl = Invoke-AgentClaude -Prompt $implPrompt
    if (-not $impl.Success) {
        Write-Fail
        Write-Host "|  Implementation failed -- skipping" -ForegroundColor Red
        Write-Host "+--"
        $failed++
        continue
    }
    Write-OK

    # Step 2: Selene fix loop
    $seleneOk = $false
    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-Step "Selene (attempt $i/$MaxRetries)"
        $selene = Invoke-Selene
        if ($selene.Success) { $seleneOk = $true; Write-OK; break }
        Write-Fail
        Write-Step "  Fixing lint"
        $fixPrompt = "Fix every selene lint error below. Do not change logic, only fix lint. Run selene src/ after and confirm it passes.`n`nErrors:`n$($selene.Output)"
        Invoke-AgentClaude -Prompt $fixPrompt -Turns 10 | Out-Null
        Write-OK
    }

    if (-not $seleneOk) {
        Write-Host "|  Selene still failing after $MaxRetries attempts -- skipping" -ForegroundColor Red
        Write-Host "+--"
        $failed++
        continue
    }

    # Step 3: Architecture review (always Claude, never DeepSeek)
    Write-Step "Architecture review"
    $reviewPrompt = @"
Read CLAUDE.md. Then run: git diff HEAD  and read every changed file.

Check for violations:
1. Does any system remove a component/tag owned by a different system?
2. Is world:has() or world:get() used inside a system body instead of in the query?
3. Is an observer used as an event (component toggled just to trigger a reaction)?
4. Does interaction layer call world:set/add/remove directly instead of EventQueue?
5. Are queries cached outside the system function?
6. Does every system file return the exact {name, phase, system} table?

Output PASS or VIOLATIONS with a list. If violations found, fix them first, then output PASS.
"@
    Invoke-AgentClaude -Prompt $reviewPrompt -Turns 15 | Out-Null
    Write-OK

    # Step 4: Final selene after review fixes
    Write-Step "Final selene"
    $final = Invoke-Selene
    if (-not $final.Success) {
        Write-Fail
        Write-Host "|  Selene failed after review fixes -- skipping commit" -ForegroundColor Red
        Write-Host "+--"
        $failed++
        continue
    }
    Write-OK

    # Step 5: Commit
    Write-Step "Committing"
    if (-not $DryRun) {
        $slug = $task -replace '[^a-zA-Z0-9\s-]', '' -replace '\s+', '-' -replace '-+', '-'
        $slug = $slug.ToLower().TrimStart('-').TrimEnd('-')
        git add -A | Out-Null
        git commit -m "agent: $slug" | Out-Null
    }
    Write-OK

    Write-Host "+-- done" -ForegroundColor Green
    Write-Host ""
    $passed++
}

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "  Passed : $passed / $total"         -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed : $failed / $total"     -ForegroundColor Red
}
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""