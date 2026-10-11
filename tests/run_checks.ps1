#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Godot = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [string[]]$Checks = @('combocheck', 'hovercheck', 'speechcheck', 'dressercheck', 'layercheck', 'state_dialogue_check', 'interaction_check', 'movement_check', 'portrait_check', 'flagcheck', 'playcombo', 'navcheck', 'authored_scene_check', 'stylized_lighting_check', 'assembly_check', 'mesh_exclusion_check', 'workshop_backend_check', 'workshop_integration_check', 'workshop_legacy_check', 'workshop_editor_check', 'workshop_head_swap_check', 'cabin_dressing_check'),
    [int]$TimeoutSeconds = 45,
    [int]$ImportTimeoutSeconds = 300,
    [switch]$SkipImport,
    [switch]$ProbeFailure,
    [switch]$RunnerSelfTest
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runPath = Join-Path ([IO.Path]::GetTempPath()) ('cruises-checks-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runPath) | Out-Null
Write-Host "Check logs: $runPath"
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot executable not found: $Godot" }

function Invoke-GodotCheck([string]$Name, [string[]]$LaunchArguments, [bool]$RequireMarker = $true, [int]$DeadlineSeconds = $TimeoutSeconds) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Godot
    $startInfo.WorkingDirectory = $projectPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $LaunchArguments) { $startInfo.ArgumentList.Add($argument) }
    if ($Name -eq 'workshop_editor_check') { $startInfo.Environment['CRUISES_WORKSHOP_EDITOR_CHECK'] = '1' }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds($DeadlineSeconds)
    $timedOut = $false
    while (-not $process.WaitForExit(500)) {
        if ([DateTime]::UtcNow -ge $deadline) {
            $process.Kill($true)
            $process.WaitForExit()
            $timedOut = $true
            break
        }
    }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $runPath ($Name + '.log')), $output)
    $engineError = $output -match '(?m)^\s*(?:SCRIPT ERROR|ERROR):'
    $reportedFailure = $output -match '(?m)^\s*(?:FAIL\b|CHECKS FAILED|[1-9][0-9]* CHECK\(S\) FAILED)'
    $hasMarker = $output -match '(?m)^\s*(?:ALL CHECKS PASSED|CHECKS PASSED:)'
    $ok = -not $timedOut -and $process.ExitCode -eq 0 -and -not $engineError -and -not $reportedFailure -and (-not $RequireMarker -or $hasMarker)
    $exitCode = $process.ExitCode
    $process.Dispose()
    [pscustomobject]@{ Name=$Name; Passed=$ok; EngineError=$engineError; TimedOut=$timedOut; ExitCode=$exitCode; HasMarker=$hasMarker; Output=$output }
}

function Get-AuthoredHashes {
    $hashes = @{}
    foreach ($path in (& git -C $projectPath ls-files)) {
        if ($path -match '\.(?:tscn|scn|tres|res|glb|gd|gdshader|json|godot|import|uid|png|jpg|jpeg|svg|ogg|wav|ttf|otf)$') {
            $absolutePath = Join-Path $projectPath $path
            if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
                if ($path.EndsWith('.import', [StringComparison]::OrdinalIgnoreCase)) {
                    # Godot may normalize these text files' line endings during import.
                    # Settings, UIDs and every other character still participate in the hash.
                    $canonical = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($absolutePath)).Replace("`r`n", "`n").Replace("`r", "`n")
                    $algorithm = [Security.Cryptography.SHA256]::Create()
                    try { $hashes[$path] = [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))).Replace('-', '') }
                    finally { $algorithm.Dispose() }
                }
                else { $hashes[$path] = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash }
            }
        }
    }
    return $hashes
}

if ($ProbeFailure) {
    $probe = Invoke-GodotCheck 'failure-probe' @('--headless','--path',$projectPath,'--script','res://tests/fixtures/runner_failure_probe.gd')
    Write-Host $probe.Output
    exit $(if ($probe.Passed) { 0 } else { 1 })
}
$before = Get-AuthoredHashes
if (-not $SkipImport) {
    $import = Invoke-GodotCheck 'import' @('--headless','--path',$projectPath,'--editor','--import','--quit') $false $ImportTimeoutSeconds
    if (-not $import.Passed) { Write-Host $import.Output; throw 'Godot import failed; see import.log.' }
}
$failures = 0
if ($RunnerSelfTest) {
    $probe = Invoke-GodotCheck 'failure-probe' @('--headless','--path',$projectPath,'--script','res://tests/fixtures/runner_failure_probe.gd')
    if ($probe.Passed -or -not $probe.EngineError -or $probe.ExitCode -ne 0 -or -not $probe.HasMarker) {
        throw 'Runner failed to reject an engine error paired with successful exit/pass marker.'
    }
    Write-Host 'PASS runner rejects deliberate engine-error false-pass'
}
foreach ($name in $Checks) {
    if ($name -notmatch '^[a-z0-9_]+$') { throw "Invalid check name: $name" }
    $scenePath = Join-Path $PSScriptRoot ($name + '.tscn')
    $launch = @('--headless','--path',$projectPath)
    if ($name -eq 'workshop_editor_check') { $launch += @('--editor', 'res://tests/fixtures/workshop_editor_check.tscn') }
    elseif (Test-Path -LiteralPath $scenePath) { $launch += 'res://tests/' + $name + '.tscn' }
    else { $launch += @('--script', "res://tests/$name.gd") }
    if ($name -eq 'mesh_exclusion_check') { $launch += @('--', '--real-assets') }
    $result = Invoke-GodotCheck $name $launch
    if ($result.Passed) { Write-Host "PASS $name" }
    else { $failures += 1; Write-Host "FAIL $name (exit=$($result.ExitCode), timeout=$($result.TimedOut), engineError=$($result.EngineError), marker=$($result.HasMarker))"; Write-Host $result.Output }
    if ($result.Passed -and $name -in @('assembly_check', 'workshop_integration_check', 'workshop_head_swap_check')) {
        $pathMarker = if ($name -eq 'workshop_integration_check') { 'COLD_WORKSHOP_ACTOR' } else { 'COLD_SCENE_PATH' }
        $coldPathMatch = [regex]::Match($result.Output, '(?m)^' + $pathMarker + '=(.+)$')
        if (-not $coldPathMatch.Success) { $failures += 1; Write-Host "FAIL $name missing cold-reopen path" }
        else {
            $coldPath = $coldPathMatch.Groups[1].Value.Trim()
            $cold = Invoke-GodotCheck ($name + '_cold') @('--headless','--path',$projectPath,'--script',"res://tests/$name.gd",'--','cold',$coldPath)
            if ($cold.Passed) { Write-Host "PASS $name cold reopen" }
            else { $failures += 1; Write-Host "FAIL $name cold reopen"; Write-Host $cold.Output }
        }
    }
    if ($result.Passed -and $name -eq 'assembly_check') {
        $nestedPathMatch = [regex]::Match($result.Output, '(?m)^COLD_NESTED_SCENE_PATH=(.+)$')
        if (-not $nestedPathMatch.Success) { $failures += 1; Write-Host 'FAIL assembly_check missing nested cold-reopen path' }
        else {
            $nested = Invoke-GodotCheck 'assembly_check_nested_cold' @('--headless','--path',$projectPath,'--script','res://tests/assembly_check.gd','--','nested',$nestedPathMatch.Groups[1].Value.Trim())
            if ($nested.Passed) { Write-Host 'PASS assembly_check nested cold reopen' }
            else { $failures += 1; Write-Host 'FAIL assembly_check nested cold reopen'; Write-Host $nested.Output }
        }
        $graphPathMatch = [regex]::Match($result.Output, '(?m)^COLD_GRAPH_SCENE_PATH=(.+)$')
        if (-not $graphPathMatch.Success) { $failures += 1; Write-Host 'FAIL assembly_check missing graph cold-reopen path' }
        else {
            $graphs = Invoke-GodotCheck 'assembly_check_graphs_cold' @('--headless','--path',$projectPath,'--script','res://tests/assembly_check.gd','--','graphs',$graphPathMatch.Groups[1].Value.Trim())
            if ($graphs.Passed) { Write-Host 'PASS assembly_check animation graphs cold reopen' }
            else { $failures += 1; Write-Host 'FAIL assembly_check animation graphs cold reopen'; Write-Host $graphs.Output }
        }
    }
}
$after = Get-AuthoredHashes
foreach ($path in $before.Keys) {
    if (-not $after.ContainsKey($path) -or $before[$path] -ne $after[$path]) {
        $failures += 1
        Write-Host "FAIL authored source changed: $path"
    }
}
if ($failures -gt 0) { Write-Host "CHECKS FAILED: $failures (logs: $runPath)"; exit 1 }
Write-Host "CHECKS PASSED: $($Checks.Count) checks; authored source unchanged (logs: $runPath)"
exit 0
