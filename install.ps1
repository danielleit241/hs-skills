[CmdletBinding()]
param(
    [string]$Ref = 'main',

    [string]$Destination,

    [switch]$Claude,

    [switch]$Codex,

    [switch]$All,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Targets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TargetPassedAsRef = @()
if ($Ref -match '^--(?:claude|codex|all)$') {
    # Windows PowerShell can bind a GNU-style flag in the first positional
    # parameter before ValueFromRemainingArguments sees it.
    $TargetPassedAsRef += $Ref
    $Ref = 'main'
}

$NamedTargets = @()
if ($Claude) { $NamedTargets += 'claude' }
if ($Codex) { $NamedTargets += 'codex' }
if ($All) { $NamedTargets += 'all' }
$RequestedTargets = @($TargetPassedAsRef + $NamedTargets)
if ($Targets) {
    $RequestedTargets += @($Targets | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $targetProject = if ([string]::IsNullOrWhiteSpace($Destination)) {
        (Get-Location).Path
    }
    else {
        [System.IO.Path]::GetFullPath($Destination)
    }
    $selectedTarget = if ($RequestedTargets -and $RequestedTargets.Count -gt 0) { $RequestedTargets[0].TrimStart('-') } else { 'all' }
    $nonce = [guid]::NewGuid().ToString('N')
    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "hs-skills-$nonce"
    $archive = "$temporaryRoot.zip"

    try {
        Invoke-WebRequest -Uri "https://github.com/danielleit241/hs-skills/archive/$Ref.zip" -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $temporaryRoot
        $installer = Get-ChildItem -LiteralPath $temporaryRoot -Recurse -File -Filter 'install.ps1' |
            Select-Object -First 1 -ExpandProperty FullName
        if ([string]::IsNullOrWhiteSpace($installer)) {
            throw "The downloaded archive does not contain install.ps1 for ref '$Ref'."
        }

        & $installer "--$selectedTarget" -Destination $targetProject
    }
    finally {
        if (Test-Path -LiteralPath $archive) {
            Remove-Item -LiteralPath $archive -Force
        }
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
    return
}

$SourceRoot = $PSScriptRoot
$DestinationRoot = if ([string]::IsNullOrWhiteSpace($Destination)) {
    $SourceRoot
}
else {
    [System.IO.Path]::GetFullPath($Destination)
}

if (Test-Path -LiteralPath $DestinationRoot -PathType Leaf) {
    throw "Destination '$DestinationRoot' must be a directory."
}
if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
}

# Platform-specific policy deliberately lives here. Agent Markdown files provide
# only their identity, delegation description, and developer instructions.
$AgentPolicies = @{
    'researcher' = @{ Tier = 'cheap'; ReadOnly = $true }
    'tester' = @{ Tier = 'cheap'; ReadOnly = $true; NeedsBash = $true }
    'project-manager' = @{ Tier = 'cheap'; ReadOnly = $false }
    'fullstack-developer' = @{ Tier = 'standard'; ReadOnly = $false }
    'docs-manager' = @{ Tier = 'standard'; ReadOnly = $false }
    'ui-ux-designer' = @{ Tier = 'standard'; ReadOnly = $false }
    'git-manager' = @{ Tier = 'standard'; ReadOnly = $false }
    'brainstormer' = @{ Tier = 'standard'; ReadOnly = $true }
    'planner' = @{ Tier = 'complex'; ReadOnly = $true }
    'debugger' = @{ Tier = 'complex'; ReadOnly = $false }
    'code-reviewer' = @{ Tier = 'complex'; ReadOnly = $true }
}

$ClaudeTiers = @{
    cheap = 'haiku'
    standard = 'sonnet'
    complex = 'opus'
}

$CodexTiers = @{
    cheap = @{ Model = 'gpt-5.6-luna'; Effort = 'light' }
    standard = @{ Model = 'gpt-5.6-terra'; Effort = 'medium' }
    complex = @{ Model = 'gpt-5.6-terra'; Effort = 'high' }
}

function Show-Usage {
    Write-Output 'Usage: .\install.ps1 --claude | --codex | --all [-Destination <project-directory>]'
}

function Resolve-Targets {
    param([string[]]$RawTargets)

    if (-not $RawTargets -or $RawTargets.Count -eq 0) {
        throw 'Choose one target: --claude, --codex, or --all.'
    }

    $normalized = @($RawTargets | ForEach-Object { $_.Trim().ToLowerInvariant().TrimStart('-') })
    if ($normalized.Count -ne 1 -or $normalized[0] -notin @('claude', 'codex', 'all')) {
        throw 'Use exactly one target: --claude, --codex, or --all.'
    }

    if ($normalized[0] -eq 'all') {
        return @('claude', 'codex')
    }

    return $normalized
}

function Read-AgentSource {
    param([System.IO.FileInfo]$File)

    $content = [System.IO.File]::ReadAllText($File.FullName)
    $match = [regex]::Match($content, '(?s)\A---\s*\r?\n(?<frontmatter>.*?)\r?\n---\s*\r?\n(?<body>.*)\z')
    if (-not $match.Success) {
        throw "Agent source '$($File.Name)' must start with YAML front matter."
    }

    $metadata = @{}
    foreach ($line in ($match.Groups['frontmatter'].Value -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $entry = [regex]::Match($line, '^(?<key>[A-Za-z][A-Za-z0-9_-]*):\s*(?<value>.*)$')
        if (-not $entry.Success) {
            throw "Unsupported front matter in '$($File.Name)': $line"
        }
        $metadata[$entry.Groups['key'].Value] = $entry.Groups['value'].Value.Trim().Trim('"').Trim("'")
    }

    foreach ($required in @('name', 'description')) {
        if (-not $metadata.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($metadata[$required])) {
            throw "Agent source '$($File.Name)' is missing required '$required' front matter."
        }
    }

    return [pscustomobject]@{
        Name = $metadata['name']
        Description = $metadata['description']
        Instructions = $match.Groups['body'].Value.Trim()
    }
}

function Get-AgentSources {
    $sources = @(Get-ChildItem -Path (Join-Path $SourceRoot 'agents') -File -Filter '*.md' | ForEach-Object { Read-AgentSource $_ })
    if ($sources.Count -eq 0) {
        throw 'No agent Markdown sources were found in agents/.'
    }

    $names = @($sources | ForEach-Object Name)
    $duplicates = @($names | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        throw "Duplicate agent names: $($duplicates -join ', ')."
    }

    foreach ($agent in $sources) {
        if (-not $AgentPolicies.ContainsKey($agent.Name)) {
            throw "No install policy is defined for agent '$($agent.Name)'."
        }
    }
    foreach ($configuredName in $AgentPolicies.Keys) {
        if ($configuredName -notin $names) {
            throw "Install policy '$configuredName' has no Markdown source."
        }
    }

    return $sources
}

function ConvertTo-TomlString {
    param([string]$Value)
    return ($Value | ConvertTo-Json -Compress)
}

function Copy-SourceDirectory {
    param(
        [string]$SourceName,
        [string]$DestinationRoot
    )

    $source = Join-Path $SourceRoot $SourceName
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw "Required source directory '$SourceName/' is missing."
    }
    Copy-Item -LiteralPath $source -Destination $DestinationRoot -Recurse -Force
}

function Normalize-CodexSkillMetadata {
    param([string]$Destination)

    $skillsRoot = Join-Path $Destination 'skills'
    foreach ($skillFile in Get-ChildItem -Path $skillsRoot -Recurse -File -Filter 'SKILL.md') {
        $content = [System.IO.File]::ReadAllText($skillFile.FullName)
        $match = [regex]::Match($content, '(?s)\A---\s*\r?\n(?<frontmatter>.*?)\r?\n---\s*\r?\n(?<body>.*)\z')
        if (-not $match.Success) {
            throw "Skill source '$($skillFile.FullName)' must start with YAML front matter."
        }

        $name = [regex]::Match($match.Groups['frontmatter'].Value, '(?m)^name:\s*(?<value>.+?)\s*$')
        $description = [regex]::Match($match.Groups['frontmatter'].Value, '(?m)^description:\s*(?<value>.+?)\s*$')
        if (-not $name.Success -or -not $description.Success) {
            throw "Skill source '$($skillFile.FullName)' must define name and description."
        }

        # Claude uses the hs: namespace and accepts argument-hint. Codex namespaces
        # plugin skills itself and only accepts its documented skill metadata keys.
        $codexName = ($name.Groups['value'].Value.Trim().Trim('"').Trim("'") -replace '^[^:]+:', '')
        if ($codexName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            throw "Codex skill name '$codexName' derived from '$($skillFile.FullName)' must be hyphen-case."
        }

        $normalized = @(
            '---',
            "name: $codexName",
            "description: $($description.Groups['value'].Value.Trim())",
            '---',
            '',
            $match.Groups['body'].Value.TrimEnd(),
            ''
        ) -join "`n"
        [System.IO.File]::WriteAllText($skillFile.FullName, $normalized, [System.Text.UTF8Encoding]::new($false))
    }
}

function Write-ClaudeAgent {
    param(
        [pscustomobject]$Agent,
        [hashtable]$Policy,
        [string]$Destination
    )

    $needsBash = $Policy.ContainsKey('NeedsBash') -and $Policy['NeedsBash']
    $frontMatter = @(
        '---',
        "name: $($Agent.Name)",
        "description: $($Agent.Description)",
        "model: $($ClaudeTiers[$Policy.Tier])"
    )

    if ($Policy.ReadOnly) {
        $tools = if ($needsBash) { 'Read, Glob, Grep, Bash' } else { 'Read, Glob, Grep' }
        $frontMatter += "tools: $tools"
        $frontMatter += 'disallowedTools: Write, Edit'
    }
    else {
        $frontMatter += 'permissionMode: default'
    }
    $frontMatter += '---'

    $output = ($frontMatter -join "`n") + "`n`n" + $Agent.Instructions + "`n"
    Set-Content -LiteralPath (Join-Path $Destination "$($Agent.Name).md") -Value $output -Encoding utf8
}

function Write-CodexAgent {
    param(
        [pscustomobject]$Agent,
        [hashtable]$Policy,
        [string]$Destination
    )

    $tier = $CodexTiers[$Policy.Tier]
    $sandbox = if ($Policy.ReadOnly) { 'read-only' } else { 'workspace-write' }
    $output = @(
        "name = $(ConvertTo-TomlString $Agent.Name)",
        "description = $(ConvertTo-TomlString $Agent.Description)",
        "model = $(ConvertTo-TomlString $tier.Model)",
        "model_reasoning_effort = $(ConvertTo-TomlString $tier.Effort)",
        "sandbox_mode = $(ConvertTo-TomlString $sandbox)",
        'developer_instructions = """',
        $Agent.Instructions,
        '"""',
        ''
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $Destination "$($Agent.Name).toml") -Value $output -Encoding utf8
}

function Read-McpConfig {
    $path = Join-Path $SourceRoot '.mcp.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw 'Missing required .mcp.json source.'
    }
    try {
        return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    }
    catch {
        throw "Invalid .mcp.json: $($_.Exception.Message)"
    }
}

function Read-RootKitConfig {
    $path = Join-Path $SourceRoot '.hs.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw 'Missing required .hs.json root kit configuration.'
    }
    try {
        return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    }
    catch {
        throw "Invalid .hs.json: $($_.Exception.Message)"
    }
}

function Assert-GuardrailConfig {
    param([object]$Config)

    $guardrailsProperty = $Config.PSObject.Properties['guardrails']
    if ($null -eq $guardrailsProperty) { return }
    if ($guardrailsProperty.Value -isnot [pscustomobject]) {
        throw '.hs.json guardrails must be an object.'
    }

    $hooksProperty = $guardrailsProperty.Value.PSObject.Properties['hooks']
    if ($null -eq $hooksProperty) { return }
    if ($hooksProperty.Value -isnot [pscustomobject]) {
        throw '.hs.json guardrails.hooks must be an object.'
    }

    $supportedHooks = @('privacy', 'scout')
    foreach ($hook in $hooksProperty.Value.PSObject.Properties) {
        if ($hook.Name -notin $supportedHooks) {
            throw "Unsupported guardrails.hooks key '$($hook.Name)'. Supported keys: $($supportedHooks -join ', ')."
        }
        if ($hook.Value -isnot [bool]) {
            throw "guardrails.hooks.$($hook.Name) must be a boolean."
        }
    }
}

function Assert-ScoutExternalConfig {
    param([object]$Config)

    $skills = $Config.PSObject.Properties['skills']
    if ($null -eq $skills -or $skills.Value -isnot [pscustomobject]) { return }
    $scout = $skills.Value.PSObject.Properties['scout']
    if ($null -eq $scout -or $scout.Value -isnot [pscustomobject]) { return }
    $external = $scout.Value.PSObject.Properties['external']
    if ($null -eq $external) { return }
    if ($external.Value -isnot [pscustomobject]) {
        throw '.hs.json skills.scout.external must be an object.'
    }

    $enabled = $external.Value.PSObject.Properties['enabled']
    if ($null -ne $enabled -and $enabled.Value -isnot [bool]) {
        throw '.hs.json skills.scout.external.enabled must be a boolean.'
    }
    $providers = $external.Value.PSObject.Properties['approvedProviders']
    if ($null -ne $providers) {
        if ($providers.Value -isnot [System.Collections.IEnumerable] -or $providers.Value -is [string]) {
            throw '.hs.json skills.scout.external.approvedProviders must be an array of provider names.'
        }
        foreach ($provider in @($providers.Value)) {
            if ($provider -notin @('gemini', 'opencode')) {
                throw ".hs.json skills.scout.external.approvedProviders contains unsupported provider '$provider'."
            }
        }
    }
}

function Ensure-GeneratedOutputGitIgnore {
    $path = Join-Path $DestinationRoot '.gitignore'
    $existing = if (Test-Path -LiteralPath $path -PathType Leaf) {
        @(Get-Content -LiteralPath $path)
    }
    else {
        @()
    }

    $requiredEntries = @('.claude/', '.codex/')
    $missingEntries = @($requiredEntries | Where-Object { $_ -notin $existing })
    if ($missingEntries.Count -gt 0) {
        Add-Content -LiteralPath $path -Value $missingEntries -Encoding utf8
        Write-Host "Updated $path with generated-output ignore rules."
    }
}

function Write-CodexConfig {
    param(
        [object]$McpConfig,
        [string]$Destination
    )

    $lines = @(
        '[agents]',
        'max_threads = 4',
        'max_depth = 1',
        ''
    )

    if ($null -ne $McpConfig.mcpServers) {
        foreach ($serverProperty in $McpConfig.mcpServers.PSObject.Properties) {
            $serverName = $serverProperty.Name.Replace('"', '\"')
            $server = $serverProperty.Value
            $commandProperty = $server.PSObject.Properties['command']
            if ($null -eq $commandProperty -or [string]::IsNullOrWhiteSpace([string]$commandProperty.Value)) {
                Write-Warning "Skipping MCP server '$($serverProperty.Name)': only stdio servers with a command are supported."
                continue
            }

            $lines += "[mcp_servers.`"$serverName`"]"
            $lines += "command = $(ConvertTo-TomlString ([string]$commandProperty.Value))"
            $argsProperty = $server.PSObject.Properties['args']
            if ($null -ne $argsProperty -and $null -ne $argsProperty.Value) {
                $arguments = @($argsProperty.Value | ForEach-Object { ConvertTo-TomlString ([string]$_) })
                $lines += "args = [$($arguments -join ', ')]"
            }
            $envConfigProperty = $server.PSObject.Properties['env']
            if ($null -ne $envConfigProperty -and $null -ne $envConfigProperty.Value) {
                $lines += "[mcp_servers.`"$serverName`".env]"
                foreach ($envProperty in $envConfigProperty.Value.PSObject.Properties) {
                    $envName = $envProperty.Name.Replace('"', '\"')
                    $lines += "`"$envName`" = $(ConvertTo-TomlString ([string]$envProperty.Value))"
                }
            }
            $lines += ''
        }
    }

    Set-Content -LiteralPath (Join-Path $Destination 'config.toml') -Value ($lines -join "`n") -Encoding utf8
}

function Write-ClaudeHooksConfig {
    param([string]$Destination)

    $settings = @{
        hooks = @{
            PreToolUse = @(
                @{
                    matcher = '.*'
                    hooks = @(
                        @{
                            type = 'command'
                            command = 'node'
                            args = @('${CLAUDE_PROJECT_DIR}/.claude/hooks/guard-rails.mjs', '--platform', 'claude')
                            timeout = 10
                            statusMessage = 'Checking hs-skills guard rails'
                        }
                    )
                }
            )
        }
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Destination 'settings.json') -Encoding utf8
}

function Write-CodexHooksConfig {
    param([string]$Destination)

    $hooks = @{
        description = 'hs-skills privacy and scout guard rails.'
        hooks = @{
            PreToolUse = @(
                @{
                    matcher = '.*'
                    hooks = @(
                        @{
                            type = 'command'
                            command = 'node "$(git rev-parse --show-toplevel)/.codex/hooks/guard-rails.mjs" --platform codex'
                            commandWindows = 'node "$(git rev-parse --show-toplevel)\.codex\hooks\guard-rails.mjs" --platform codex'
                            timeout = 10
                            statusMessage = 'Checking hs-skills guard rails'
                        }
                    )
                }
            )
        }
    }
    $hooks | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $Destination 'hooks.json') -Encoding utf8
}

function Replace-GeneratedDirectory {
    param(
        [string]$StagedDirectory,
        [string]$TargetDirectory
    )

    $backup = "$TargetDirectory.backup-$([guid]::NewGuid().ToString('N'))"
    if (Test-Path -LiteralPath $TargetDirectory) {
        Move-Item -LiteralPath $TargetDirectory -Destination $backup
    }
    try {
        Move-Item -LiteralPath $StagedDirectory -Destination $TargetDirectory
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Recurse -Force
        }
    }
    catch {
        if (Test-Path -LiteralPath $backup -and -not (Test-Path -LiteralPath $TargetDirectory)) {
            Move-Item -LiteralPath $backup -Destination $TargetDirectory
        }
        throw
    }
}

try {
    $selectedTargets = Resolve-Targets $RequestedTargets
    $agents = Get-AgentSources
    $kitConfig = Read-RootKitConfig
    Assert-GuardrailConfig $kitConfig
    Assert-ScoutExternalConfig $kitConfig
    $mcpConfig = Read-McpConfig
    Ensure-GeneratedOutputGitIgnore
    $stagingRoot = Join-Path $DestinationRoot ".install-staging-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $stagingRoot | Out-Null

    try {
        foreach ($target in $selectedTargets) {
            if ($target -eq 'claude') {
                $claudeRoot = Join-Path $stagingRoot '.claude'
                $agentsDestination = Join-Path $claudeRoot 'agents'
                New-Item -ItemType Directory -Path $agentsDestination -Force | Out-Null
                foreach ($agent in $agents) { Write-ClaudeAgent $agent $AgentPolicies[$agent.Name] $agentsDestination }
                Copy-SourceDirectory 'skills' $claudeRoot
                Copy-SourceDirectory 'commands' $claudeRoot
                Copy-SourceDirectory 'hooks' $claudeRoot
                Write-ClaudeHooksConfig $claudeRoot
            }
            elseif ($target -eq 'codex') {
                $codexRoot = Join-Path $stagingRoot '.codex'
                $agentsDestination = Join-Path $codexRoot 'agents'
                New-Item -ItemType Directory -Path $agentsDestination -Force | Out-Null
                foreach ($agent in $agents) { Write-CodexAgent $agent $AgentPolicies[$agent.Name] $agentsDestination }
                Write-CodexConfig $mcpConfig $codexRoot
                Copy-SourceDirectory 'skills' $codexRoot
                Normalize-CodexSkillMetadata $codexRoot
                Copy-SourceDirectory 'hooks' $codexRoot
                Write-CodexHooksConfig $codexRoot
            }
        }

        foreach ($target in $selectedTargets) {
            $targetDirectory = Join-Path $DestinationRoot ".${target}"
            Replace-GeneratedDirectory (Join-Path $stagingRoot ".${target}") $targetDirectory
            Write-Host "Generated $targetDirectory"
        }
    }
    finally {
        if (Test-Path -LiteralPath $stagingRoot) {
            Remove-Item -LiteralPath $stagingRoot -Recurse -Force
        }
    }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    Show-Usage
    exit 1
}
