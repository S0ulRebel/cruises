#requires -Version 7.0
[CmdletBinding()]
param([string]$Godot = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('workshop-portability-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$package = Join-Path $fixture 'character_workshop.zip'
& (Join-Path $source 'tools/package_character_workshop.ps1') -OutputPath $package
[IO.Compression.ZipFile]::ExtractToDirectory($package, $fixture)
foreach ($folder in @('assets','other','characters','templates','verification')) { [IO.Directory]::CreateDirectory((Join-Path $fixture $folder)) | Out-Null }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/workshop_editor_model.tscn') -Destination (Join-Path $fixture 'assets/source.tscn')
$modelPath = Join-Path $fixture 'assets/source.tscn'
$modelText = [IO.File]::ReadAllText($modelPath).Replace('NodePath("Skeleton:Jaw")', 'NodePath("Skeleton:Hips")')
$hips = @'
bones/2/name = "Hips"
bones/2/parent = -1
bones/2/rest = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)
bones/2/enabled = true
bones/2/position = Vector3(0, 0, 0)
bones/2/rotation = Quaternion(0, 0, 0, 1)
bones/2/scale = Vector3(1, 1, 1)

'@
[IO.File]::WriteAllText($modelPath, $modelText.Replace('[node name="CollisionBody"', $hips + "`n[node name=`"CollisionBody`""))
Copy-Item -LiteralPath (Join-Path $source 'art/props/key/key.glb') -Destination (Join-Path $fixture 'assets/source.glb')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/workshop_editor_model.tscn') -Destination (Join-Path $fixture 'other/hidden.tscn')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/workshop_portable_runner.gd') -Destination (Join-Path $fixture 'verification/runner.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/workshop_portable_runtime.gd') -Destination (Join-Path $fixture 'verification/runtime.gd')
[IO.File]::WriteAllText((Join-Path $fixture 'templates/custom.tscn'), @'
[gd_scene format=3]
[ext_resource type="Script" path="res://addons/character_workshop/runtime/assembly.gd" id="assembly"]
[node name="CustomStarter" type="Node3D"]
script = ExtResource("assembly")
'@)
[IO.File]::WriteAllText((Join-Path $fixture 'verification/editor.tscn'), @'
[gd_scene format=3]
[ext_resource type="Script" path="res://addons/character_workshop/runtime/assembly.gd" id="assembly"]
[ext_resource type="Script" path="res://verification/runner.gd" id="runner"]
[node name="PortableCharacter" type="Node3D"]
script = ExtResource("assembly")
[node name="Runner" type="Node" parent="."]
script = ExtResource("runner")
'@)
$settings = @'
config_version=5
[application]
config/name="Independent Workshop Verification"
[rendering]
renderer/rendering_method="gl_compatibility"
'@
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $settings)
function Run-Phase([string]$Name, [string[]]$Arguments, [bool]$Marker, [string]$WorkingDirectory = $fixture) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $Godot
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.Environment['WORKSHOP_PORTABLE_CHECK'] = '1'
    foreach ($arg in $Arguments) { $start.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit(90000)
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $fixture ($Name + '.log')), $log)
    if ($timedOut -or $process.ExitCode -ne 0 -or $log -match '(?m)^\s*(?:SCRIPT ERROR|ERROR:|PORTABLE_FAIL:)' -or ($Marker -and $log -notmatch 'CHECKS PASSED:')) { Write-Host $log; throw "$Name failed; see $fixture" }
    $process.Dispose()
    Write-Host "PASS $Name"
}
Run-Phase 'fresh-import' @('--headless','--path',$fixture,'--editor','--import','--quit') $false
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $settings + "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/character_workshop/plugin.cfg`")`n")
Run-Phase 'native-authoring' @('--headless','--path',$fixture,'--editor','res://verification/editor.tscn') $true
$content = [IO.File]::ReadAllText((Join-Path $fixture 'project.godot'))
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $content.Replace('enabled=PackedStringArray("res://addons/character_workshop/plugin.cfg")','enabled=PackedStringArray()'))
Run-Phase 'cold-disabled-plugin' @('--headless','--path',$fixture,'res://characters/assembled.tscn','--','cold') $true
$gameSettings = [IO.File]::ReadAllText((Join-Path $fixture 'project.godot')).Replace('[application]', "[application]`nrun/main_scene=`"res://characters/assembled.tscn`"")
[IO.File]::WriteAllText((Join-Path $fixture 'project.godot'), $gameSettings)
$exportRules = [regex]::Match([IO.File]::ReadAllText((Join-Path $source 'export_presets.cfg')), '(?m)^exclude_filter=.*$').Value.Trim()
# Only the runtime verifier belongs in the exported fixture.
$exportRules = $exportRules.TrimEnd('"') + ',verification/runner.gd,verification/editor.tscn"'
[IO.File]::WriteAllText((Join-Path $fixture 'export_presets.cfg'), @"
[preset.0]
name="Runtime"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter=""
$exportRules
[preset.0.options]
binary_format/architecture="x86_64"
"@)
$pack = Join-Path $fixture 'runtime.pck'
Run-Phase 'export-runtime-pack' @('--headless','--path',$fixture,'--editor','--export-pack','Runtime',$pack) $false
# Run outside the authoring project: Godot can otherwise resolve excluded files
# from the source directory beside the pack and hide missing runtime dependencies.
$runtimeOnly = Join-Path $fixture 'runtime_only'
[IO.Directory]::CreateDirectory($runtimeOnly) | Out-Null
Run-Phase 'cold-exported-pack' @('--headless','--path',$runtimeOnly,'--main-pack',$pack,'--','cold','exported') $true $runtimeOnly
Write-Host "CHECKS PASSED: portable addon; fixture/logs: $fixture"
