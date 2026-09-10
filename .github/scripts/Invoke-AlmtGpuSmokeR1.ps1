[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$EventPath,
    [Parameter(Mandatory = $true)] [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$expectedRepository = 'jts-peppa/ALMT'
$expectedOwner = 'jts-peppa'
$localRepository = 'E:\ALMT'
$python = 'D:\Users\123\anaconda3\envs\ALMT\python.exe'
$config = 'E:\ALMT\configs\mosi_runner_smoke_local.yaml'
$expectedConfigHash = '361d2b630db3d44d1f0fbca7da08e59a5f112e9ef484af1f0d25be25ecd14058'

$event = Get-Content -LiteralPath $EventPath -Raw | ConvertFrom-Json
if ($event.repository.full_name -ne $expectedRepository) { throw 'Unexpected repository.' }
if ($event.sender.login -ne $expectedOwner) { throw 'The gpu-approved label was not applied by the repository owner.' }
if ($event.issue.user.login -ne $expectedOwner) { throw 'The task Issue was not created by the repository owner.' }
if ($event.label.name -cne 'gpu-approved') { throw 'This workflow only accepts the gpu-approved label event.' }
if ($event.issue.title -notmatch '^\[(ALMT-TASK-[0-9]+)\]\s+.{1,120}$') { throw 'Invalid task title.' }
$taskId = $matches[1]

$labels = @($event.issue.labels | ForEach-Object { $_.name })
foreach ($required in @('approved', 'gpu-approved')) {
    if ($labels -notcontains $required) { throw "Missing required label: $required" }
}

if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { throw 'The workflow token is unavailable.' }
$apiHeaders = @{
    Authorization = "Bearer $env:GH_TOKEN"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = 'ALMT-GPU-R1'
}
$openItems = Invoke-RestMethod -Headers $apiHeaders -Uri 'https://api.github.com/repos/jts-peppa/ALMT/issues?state=open&per_page=100'
$eligibleTasks = @($openItems | Where-Object {
    $null -eq $_.PSObject.Properties['pull_request'] -and
    $_.title -match '^\[ALMT-TASK-' -and
    @($_.labels | ForEach-Object { $_.name }) -contains 'approved' -and
    @($_.labels | ForEach-Object { $_.name }) -contains 'gpu-approved'
})
if ($eligibleTasks.Count -ne 1 -or $eligibleTasks[0].number -ne $event.issue.number) {
    throw "Expected exactly one approved GPU task matching this Issue; found $($eligibleTasks.Count)."
}

$body = [string]$event.issue.body
if ($body -notmatch '(?im)^Status:\s*(PROPOSED|READY)\s*$') { throw 'Missing valid task status.' }
if ($body -notmatch '(?im)^Experiment Type:\s*ALMT_MOSI_BASELINE_SMOKE_R1\s*$') { throw 'Unexpected experiment type.' }
if ($body -notmatch '(?im)^Seed:\s*1111\s*$') { throw 'Only Seed 1111 is permitted in R1.' }
if ($body -notmatch '(?im)^Max Epochs:\s*1\s*$') { throw 'R1 is limited to one epoch.' }
if ($body -notmatch '(?im)^Evaluate Test:\s*false\s*$') { throw 'Test evaluation must be disabled.' }
if ($body -notmatch '(?im)^Source Commit:\s*([0-9a-f]{40})\s*$') { throw 'Missing full Source Commit.' }
$expectedCommit = $matches[1]
if ($body -notmatch "(?im)^Config SHA256:\s*$expectedConfigHash\s*$") { throw 'Local configuration hash is not approved.' }

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw 'Approved ALMT Python interpreter is missing.' }
if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Approved local smoke configuration is missing.' }
$actualConfigHash = (Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualConfigHash -ne $expectedConfigHash) { throw 'Local smoke configuration changed after approval.' }

Push-Location -LiteralPath $localRepository
try {
    if ((git branch --show-current) -ne 'master') { throw 'Local ALMT checkout is not on master.' }
    $dirty = @(git status --porcelain=v1 --untracked-files=all)
    if ($dirty.Count -ne 0) { throw "Local ALMT checkout is dirty: $($dirty -join '; ')" }
    $head = git rev-parse HEAD
    if ($head -ne $expectedCommit) { throw "Source commit mismatch: expected $expectedCommit, found $head" }

    $usedMemory = [int]((& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | Select-Object -First 1).Trim())
    if ($usedMemory -gt 1500) { throw "GPU is already occupied ($usedMemory MiB used)." }

    $logDir = Join-Path $localRepository 'log\runner'
    [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    $logPath = Join-Path $logDir "$taskId-r1-smoke.log"
    $started = [DateTimeOffset]::UtcNow
    & $python 'train.py' '--config_file' $config '--seed' '1111' '--gpu_id' '0' '--stop_after_epoch' '1' 2>&1 | Tee-Object -FilePath $logPath
    if ($LASTEXITCODE -ne 0) { throw "ALMT R1 smoke training failed with exit code $LASTEXITCODE." }
    $finished = [DateTimeOffset]::UtcNow

    $checkpointDir = Join-Path $localRepository 'ckpt\ALMT_MOSI_runner_smoke_r1'
    $lastCheckpoint = Join-Path $checkpointDir 'last_seed1111.pth'
    $bestCheckpoint = Join-Path $checkpointDir 'best_valid_seed1111.pth'
    $auditPath = Join-Path $checkpointDir 'audit_seed1111.json'
    foreach ($requiredPath in @($lastCheckpoint, $bestCheckpoint, $auditPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Missing smoke artifact: $requiredPath" }
    }
    $audit = Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json
    if ($audit.test_evaluation_requested -ne $false) { throw 'Audit indicates Test evaluation was requested.' }

    $lastLine = Select-String -LiteralPath $logPath -Pattern '^Epoch audit:' | Select-Object -Last 1
    $report = @"
# EXP-001

Status: PRELIMINARY
Experiment Type: GPU_SMOKE
Task ID: $taskId
Source Issue: #$($event.issue.number)
Source Commit: $head
Config SHA256: $actualConfigHash

## Goal

Verify the approved-label to local-GPU ALMT training path with one epoch and no Test access.

## Configuration

- Dataset: MOSI aligned features
- Seed: 1111
- Maximum epochs: 1
- Physical batch size: 4
- Gradient accumulation: 16
- Test evaluation: false

## Result

- Training process exit: success
- Best checkpoint exists: true
- Last checkpoint exists: true
- Audit exists: true
- Test evaluation requested: false
- Started UTC: $($started.ToString('o'))
- Finished UTC: $($finished.ToString('o'))
- Duration seconds: $([Math]::Round(($finished - $started).TotalSeconds, 2))
- Epoch audit: $($lastLine.Line)

## Conclusion

Preliminary infrastructure result only. This smoke run does not establish ALMT baseline performance or support any innovation claim.
"@
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($ReportPath)) | Out-Null
    [System.IO.File]::WriteAllText($ReportPath, $report, [System.Text.UTF8Encoding]::new($false))
}
finally {
    Pop-Location
}
