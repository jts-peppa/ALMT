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
$config = 'E:\ALMT\configs\mosi_runner_baseline_seed1111_local.yaml'
$expectedConfigHash = 'a0cedb8c78820a6936e3e150675725b3d1e5895379bba3c1661fdf19ac9d5718'

$event = Get-Content -LiteralPath $EventPath -Raw | ConvertFrom-Json
if ($event.repository.full_name -ne $expectedRepository) { throw 'Unexpected repository.' }
if ($event.sender.login -ne $expectedOwner) { throw 'gpu-approved was not applied by the owner.' }
if ($event.issue.user.login -ne $expectedOwner) { throw 'Task Issue was not created by the owner.' }
if ($event.label.name -cne 'gpu-approved') { throw 'Unexpected trigger label.' }
$labels = @($event.issue.labels | ForEach-Object { $_.name })
foreach ($required in @('approved', 'gpu-approved')) { if ($labels -notcontains $required) { throw "Missing label: $required" } }

$body = [string]$event.issue.body
if ($event.issue.title -notmatch '^\[(ALMT-TASK-[0-9]+)\]\s+.{1,120}$') { throw 'Invalid task title.' }
$taskId = $matches[1]
foreach ($contract in @(
    '(?im)^Status:\s*(PROPOSED|READY)\s*$',
    '(?im)^Experiment Type:\s*ALMT_MOSI_BASELINE_FORMAL_R2\s*$',
    '(?im)^Dataset:\s*MOSI_ALIGNED_50\s*$',
    '(?im)^Seed:\s*1111\s*$',
    '(?im)^Max Epochs:\s*200\s*$',
    '(?im)^Evaluate Test Once:\s*true\s*$'
)) { if ($body -notmatch $contract) { throw "Missing fixed contract field: $contract" } }
if ($body -notmatch '(?im)^Source Commit:\s*([0-9a-f]{40})\s*$') { throw 'Missing Source Commit.' }
$expectedCommit = $matches[1]
if ($body -notmatch "(?im)^Config SHA256:\s*$expectedConfigHash\s*$") { throw 'Config hash is not approved.' }
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) { throw 'Approved Python is missing.' }
if (-not (Test-Path -LiteralPath $config -PathType Leaf)) { throw 'Approved config is missing.' }
if ((Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedConfigHash) { throw 'Local config changed.' }

Push-Location -LiteralPath $localRepository
try {
    if ((git branch --show-current) -ne 'master') { throw 'Local checkout is not on master.' }
    $dirty = @(git status --porcelain=v1 --untracked-files=all)
    if ($dirty.Count -ne 0) { throw "Local checkout is dirty: $($dirty -join '; ')" }
    $head = git rev-parse HEAD
    if ($head -ne $expectedCommit) { throw "Source mismatch: expected $expectedCommit, found $head" }
    $usedMemory = [int]((& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | Select-Object -First 1).Trim())
    if ($usedMemory -gt 1500) { throw "GPU is already occupied ($usedMemory MiB used)." }

    $checkpointDir = Join-Path $localRepository 'ckpt\ALMT_MOSI_baseline_seed1111_r2'
    $lastCheckpoint = Join-Path $checkpointDir 'last_seed1111.pth'
    $completionPath = Join-Path $checkpointDir 'formal_completion_seed1111.json'
    if (Test-Path -LiteralPath $completionPath -PathType Leaf) { throw 'Formal experiment already completed; refusing to evaluate Test again.' }
    $logDir = Join-Path $localRepository 'log\runner'
    [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    $logPath = Join-Path $logDir "$taskId-r2-baseline.log"
    $arguments = @('train.py','--config_file',$config,'--seed','1111','--gpu_id','0','--evaluate_test')
    $resumed = Test-Path -LiteralPath $lastCheckpoint -PathType Leaf
    if ($resumed) { $arguments += @('--resume','auto') }
    $started = [DateTimeOffset]::UtcNow
    & $python @arguments 2>&1 | Tee-Object -FilePath $logPath -Append
    if ($LASTEXITCODE -ne 0) { throw "Training failed with exit code $LASTEXITCODE; retain epoch checkpoint for resume." }
    $finished = [DateTimeOffset]::UtcNow

    $bestCheckpoint = Join-Path $checkpointDir 'best_valid_seed1111.pth'
    $auditPath = Join-Path $checkpointDir 'audit_seed1111.json'
    foreach ($path in @($lastCheckpoint,$bestCheckpoint,$auditPath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing artifact: $path" } }
    $audit = Get-Content -LiteralPath $auditPath -Raw | ConvertFrom-Json
    if ($audit.test_evaluation_requested -ne $true) { throw 'Audit does not confirm explicit Test evaluation.' }
    $testLine = Select-String -LiteralPath $logPath -Pattern '^Final Test Results ' | Select-Object -Last 1
    $totalLine = Select-String -LiteralPath $logPath -Pattern '^Total run seconds:' | Select-Object -Last 1
    if ($null -eq $testLine -or $null -eq $totalLine) { throw 'Final Test result or timing line is missing.' }
    $epochLines = @(Select-String -LiteralPath $logPath -Pattern '^Epoch audit:')
    $peakValues = @($epochLines | ForEach-Object { if ($_.Line -match 'peak_cuda_allocated_mib=([0-9.]+)') { [double]$matches[1] } })
    $peak = if ($peakValues.Count) { ($peakValues | Measure-Object -Maximum).Maximum } else { 'UNKNOWN' }
    $completion = @{source_commit=$head;config_hash=$expectedConfigHash;seed=1111;test_result=$testLine.Line;finished_utc=$finished.ToString('o')} | ConvertTo-Json
    $completionTmp = "$completionPath.tmp"
    Set-Content -LiteralPath $completionTmp -Value $completion -Encoding utf8
    Move-Item -LiteralPath $completionTmp -Destination $completionPath -Force

    $report = @"
# EXP-002

Status: PRELIMINARY
Experiment Type: FORMAL_BASELINE_SINGLE_SEED
Task ID: $taskId
Source Issue: #$($event.issue.number)
Source Commit: $head
Config SHA256: $expectedConfigHash

## Goal

Reproduce the frozen ALMT baseline on MOSI aligned features for Seed 1111.

## Protocol

- Dataset: MOSI aligned (`aligned_50.pkl`, lengths 50/50/50)
- Seed: 1111
- Fixed schedule: 200 epochs; no early stopping
- Selection: best Valid MAE checkpoint
- Test: evaluated exactly once after training from the best-Valid checkpoint
- Physical/effective batch size: 4/64
- Learning rate / weight decay: 0.0001 / 0.0001
- DataLoader workers / GPU ID: 0 / 0
- Input dimensions (text/audio/vision): 768/5/20
- Input lengths (text/audio/vision): 50/50/50
- Projection dimensions: 128/128/128; depth/heads/MLP: 1/8/128
- Token length/dimension: 8/128
- Text encoder heads/MLP: 8/128
- AHL depth/heads/head dimension/dropout: 3/8/16/0.0
- Fusion heads/MLP/depth: 8/128/2
- Resume used for this invocation: $resumed

## Results

- $($testLine.Line)
- $($totalLine.Line)
- Peak CUDA allocated MiB across logged epochs: $peak
- Started UTC: $($started.ToString('o'))
- Finished UTC: $($finished.ToString('o'))

## Artifacts

Best/last checkpoints, audit JSON, TensorBoard data, and the complete console log remain local and ignored. No model weight or raw log is committed.

## Conclusion

PRELIMINARY: this is one formal baseline seed. It must not be described as a stable multi-seed reproduction or an innovation result.
"@
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $ReportPath)) | Out-Null
    Set-Content -LiteralPath $ReportPath -Value $report -Encoding utf8
}
finally { Pop-Location }
