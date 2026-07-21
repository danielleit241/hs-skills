[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SourceRoot = Split-Path -Parent $PSScriptRoot
$TemporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hs-skills-install-test-$([guid]::NewGuid().ToString('N'))"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Copy-TestWorkspace {
    param([string]$Destination)

    New-Item -ItemType Directory -Path $Destination | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $SourceRoot -Force) {
        if ($item.Name -in @('.git', '.claude', '.codex')) { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $Destination -Recurse -Force
    }
}

function Get-AgentHashes {
    param([string]$Workspace)
    return @(
        Get-ChildItem -LiteralPath (Join-Path $Workspace 'agents') -Filter '*.md' -File |
            Sort-Object Name |
            ForEach-Object { "$( $_.Name ):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }
    )
}

try {
    Copy-TestWorkspace $TemporaryRoot
    $installer = Join-Path $TemporaryRoot 'install.ps1'
    $beforeHashes = Get-AgentHashes $TemporaryRoot
    Remove-Item -LiteralPath (Join-Path $TemporaryRoot '.gitignore') -Force

    & $installer --claude
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.hs.json')) 'The shared root .hs.json kit configuration is retained.'
    $gitIgnore = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.gitignore') -Raw
    Assert-True ($gitIgnore -match '(?m)^\.claude/\r?$') 'Generated Claude output is ignored.'
    Assert-True ($gitIgnore -match '(?m)^\.codex/\r?$') 'Generated Codex output is ignored.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.claude\agents\researcher.md')) '--claude creates Claude agents.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.claude\skills\hs-plan\SKILL.md')) '--claude copies skills.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.claude\commands\hs\plan.md')) '--claude copies commands.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.claude\hooks\guard-rails.mjs')) '--claude copies guard-rail source.'
    $claudeSettings = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.claude\settings.json') -Raw
    Assert-True ($claudeSettings -match 'guard-rails\.mjs') '--claude wires guard rails.'
    $claudeHook = ($claudeSettings | ConvertFrom-Json).hooks.PreToolUse[0].hooks[0]
    Assert-True ($claudeHook.command -eq 'node') 'Claude guard rails use command exec form.'
    Assert-True ($claudeHook.args[0] -eq '${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-rails.mjs') 'Claude guard rails resolve from the project directory.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex'))) '--claude leaves Codex output untouched.'
    $claudeResearcher = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.claude\agents\researcher.md') -Raw
    Assert-True ($claudeResearcher -match 'model: haiku') 'Cheap Claude agents use haiku.'
    $claudePlanner = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.claude\agents\planner.md') -Raw
    Assert-True ($claudePlanner -match 'model: opus') 'Complex Claude agents use opus.'

    & $installer --codex
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex\agents\researcher.toml')) '--codex creates Codex agents.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex\skills\hs-plan\SKILL.md')) '--codex copies skills.'
    $codexPlanSkill = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\skills\hs-plan\SKILL.md') -Raw
    Assert-True ($codexPlanSkill -match '(?m)^name: plan$') 'Codex skill metadata removes the Claude namespace.'
    Assert-True ($codexPlanSkill -notmatch '(?m)^argument-hint:') 'Codex skill metadata removes unsupported Claude-only fields.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex\commands'))) '--codex does not copy unsupported commands.'
    $codexResearcher = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\agents\researcher.toml') -Raw
    Assert-True ($codexResearcher -match 'model = "gpt-5.6-luna"') 'Cheap Codex agents use gpt-5.6-luna.'
    Assert-True ($codexResearcher -match 'model_reasoning_effort = "light"') 'Cheap Codex agents use light reasoning.'
    $codexDeveloper = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\agents\fullstack-developer.toml') -Raw
    Assert-True ($codexDeveloper -match 'model = "gpt-5.6-terra"') 'Standard Codex agents use terra.'
    Assert-True ($codexDeveloper -match 'model_reasoning_effort = "medium"') 'Standard Codex agents use medium reasoning.'
    $codexReviewer = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\agents\code-reviewer.toml') -Raw
    Assert-True ($codexReviewer -match 'model_reasoning_effort = "high"') 'Complex Codex agents use high reasoning.'
    $codexConfig = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\config.toml') -Raw
    Assert-True ($codexConfig -match 'max_threads = 4') 'Codex config caps concurrent threads.'
    Assert-True ($codexConfig -match '\[mcp_servers\."sequential-thinking"\]') 'Codex config converts MCP servers.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex\hooks\guard-rails.mjs')) '--codex copies guard-rail source.'
    $codexHooks = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.codex\hooks.json') -Raw
    Assert-True ($codexHooks -match 'guard-rails\.mjs') '--codex wires guard rails.'
    $codexHook = ($codexHooks | ConvertFrom-Json).hooks.PreToolUse[0].hooks[0]
    Assert-True ($codexHook.command -match 'git rev-parse --show-toplevel') 'Codex guard rails resolve from the git root.'
    Assert-True ($codexHook.commandWindows -match 'git rev-parse --show-toplevel') 'Codex guard rails define a Windows git-root command.'

    Remove-Item -LiteralPath (Join-Path $TemporaryRoot '.claude') -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $TemporaryRoot '.codex') -Recurse -Force
    & $installer --all
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.claude')) '--all creates Claude output.'
    Assert-True (Test-Path -LiteralPath (Join-Path $TemporaryRoot '.codex')) '--all creates Codex output.'

    $shellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    $shellExecutable = Join-Path $PSHOME $shellName
    $nativeErrorPreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($nativeErrorPreference) { $PSNativeCommandUseErrorActionPreference = $false }
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $shellExecutable -NoProfile -File $installer 2>&1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($nativeErrorPreference) { $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference.Value }
    }
    Assert-True ($LASTEXITCODE -eq 1) 'Missing target fails.'
    Assert-True (($output -join "`n") -match 'Usage:') 'Missing target reports usage.'

    $invalidConfig = Get-Content -LiteralPath (Join-Path $TemporaryRoot '.hs.json') -Raw | ConvertFrom-Json
    $invalidConfig.guardrails = [pscustomobject]@{
        hooks = [pscustomobject]@{ privacy = 'true' }
    }
    $invalidConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $TemporaryRoot '.hs.json') -Encoding utf8
    $output = & $installer --claude 2>&1
    Assert-True ($LASTEXITCODE -eq 1) 'Invalid guardrail hook config fails.'

    $invalidScoutConfig = Get-Content -LiteralPath (Join-Path $SourceRoot '.hs.json') -Raw | ConvertFrom-Json
    $invalidScoutConfig.skills.scout.external.approvedProviders = @('unknown-provider')
    $invalidScoutConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $TemporaryRoot '.hs.json') -Encoding utf8
    $output = & $installer --claude 2>&1
    Assert-True ($LASTEXITCODE -eq 1) 'Invalid external scout provider config fails.'

    Assert-True (((Get-AgentHashes $TemporaryRoot) -join '|') -ceq ($beforeHashes -join '|')) 'Installer never changes agent sources.'

    Write-Host 'install.ps1 smoke tests passed.'
}
finally {
    if (Test-Path -LiteralPath $TemporaryRoot) {
        Remove-Item -LiteralPath $TemporaryRoot -Recurse -Force
    }
}
