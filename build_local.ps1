[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -- Paths --
$repoRoot    = Split-Path -Parent $PSScriptRoot   # c:\Git
$ddeInternal = Join-Path $repoRoot 'dde\internal'
$csproj      = Join-Path $PSScriptRoot 'DotNetBuildPipeline.csproj'

# -- 1. Prepare DDE auth (registers PS repo + installs DDE.Environment / DDE.Artifactory / DDE.NuGet) --
$prepareScript = Join-Path $repoRoot 'cmps-scripts\prepare.ps1'
if (Test-Path $prepareScript) {
    Write-Host '[build_local] Running prepare.ps1 (DDE auth setup)...'
    & $prepareScript
} else {
    throw "prepare.ps1 not found at $prepareScript"
}

# -- 2. Retrieve the stored JFrog credential and configure the NuGet source for dotnet restore --
# DDE stores credentials in DDESecretStore; prepare.ps1 already unlocked the vault above.
$jfrogCred = Get-Secret -Name 'jfrog' -Vault 'DDESecretStore'
$nugetSourceName = 'rbwcwh-nuget-virtual'
Write-Host "[build_local] Updating NuGet source '$nugetSourceName' with stored credentials..."
dotnet nuget update source $nugetSourceName `
    --username $jfrogCred.UserName `
    --password $jfrogCred.GetNetworkCredential().Password `
    --store-password-in-clear-text `
    --configfile (Join-Path $repoRoot 'nuget.config')

# -- 3. Import DDE.Dotnet directly from the local dde folder --
$ddeDotnetModule = Join-Path $ddeInternal 'DDE.Dotnet\DDE.Dotnet.psm1'
if (-not (Test-Path $ddeDotnetModule)) {
    throw "DDE.Dotnet module not found at: $ddeDotnetModule"
}
Write-Host "[build_local] Importing DDE.Dotnet from $ddeDotnetModule"
Import-Module $ddeDotnetModule -Force

# -- 4. Build --
Write-Host "[build_local] Building $csproj ($Configuration)..."
Invoke-DotnetBuild -path $csproj -configuration $Configuration
