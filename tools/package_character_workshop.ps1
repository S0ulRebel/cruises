#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$pluginPath = Join-Path $projectPath 'addons/character_workshop'
$output = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $output) { throw "Output already exists: $output" }
if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($output)) -PathType Container)) { throw 'Choose an existing output directory.' }
Add-Type -AssemblyName System.IO.Compression
$archive = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $pluginPath -Recurse -File) {
        if ($file.Extension -notin @('.gd','.uid','.tscn','.cfg','.md')) { continue }
        if ($file.Name -in @('AGENTS.md','HANDOFF.md')) { continue }
        $relative = [IO.Path]::GetRelativePath($pluginPath, $file.FullName).Replace('\','/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, 'addons/character_workshop/' + $relative, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }
Write-Host "Character Workshop package: $output"
