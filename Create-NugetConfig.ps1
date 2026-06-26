<#
.SYNOPSIS
    Generates a nuget.config with Vanderlande Artifactory source credentials at runtime.
    Inspired by cmps-scripts/createAcpNugetConfig.ps1 (DDE pattern).

.DESCRIPTION
    Creates a fresh nuget.config in the specified output path, registers nuget.org and the
    rbwcwh-nuget-virtual Artifactory source, then injects credentials.
    Designed to be called in CI (GitHub Actions) and locally without DDE module dependencies.

.PARAMETER Username
    Artifactory username (e.g. firstname.lastname@vanderlande.com).

.PARAMETER Password
    Artifactory identity token / API key.

.PARAMETER OutputPath
    Directory where nuget.config will be written. Defaults to the script's own directory.

.EXAMPLE
    .\Create-NugetConfig.ps1 -Username $env:ARTIFACTORY_USER -Password $env:ARTIFACTORY_TOKEN
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Username,

    [Parameter(Mandatory)]
    [string] $Password,

    [string] $OutputPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$configFile = Join-Path $OutputPath 'nuget.config'

# Remove any existing config so we start clean
if (Test-Path $configFile) {
    Remove-Item $configFile -Force
}

# Create a blank nuget.config via the dotnet CLI (same approach as DDE scripts)
dotnet new nugetconfig --name nuget --output $OutputPath --force | Out-Null

# Remove the default nuget.org source that dotnet adds, then add our controlled sources
$artifactoryUrl = 'https://artifactory.vanderlande.com/artifactory/api/nuget/v3/rbwcwh-nuget-virtual'
$sourceName     = 'rbwcwh-nuget-virtual'

# Add nuget.org
dotnet nuget add source 'https://api.nuget.org/v3/index.json' `
    --name 'nuget.org' `
    --configfile $configFile

# Add Vanderlande Artifactory source with credentials
dotnet nuget add source $artifactoryUrl `
    --name $sourceName `
    --username $Username `
    --password $Password `
    --store-password-in-clear-text `
    --configfile $configFile

Write-Host "[Create-NugetConfig] nuget.config written to: $configFile"
