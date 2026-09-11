[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$EventPath,
    [Parameter(Mandatory=$true)][string]$ReportPath
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo='E:\ALMT'
$python='D:\Users\123\anaconda3\envs\ALMT\python.exe'
$config='E:\ALMT\configs\mosi_runner_baseline_seed1111_local.yaml'
$configHash='a0cedb8c78820a6936e3e150675725b3d1e5895379bba3c1661fdf19ac9d5718'
$sourceHash='287babe313e70667c0df7d261e467cd634c670a0370108924594e6b3511e5072'
$event=Get-Content -LiteralPath $EventPath -Raw|ConvertFrom-Json
if($event.repository.full_name -ne 'jts-peppa/ALMT' -or $event.sender.login -ne 'jts-peppa' -or $event.issue.user.login -ne 'jts-peppa'){throw 'Untrusted event.'}
if($event.label.name -cne 'gpu-approved'){throw 'Unexpected trigger.'}
$labels=@($event.issue.labels|ForEach-Object{$_.name});foreach($x in @('approved','gpu-approved')){if($labels -notcontains $x){throw "Missing label: $x"}}
$body=[string]$event.issue.body
foreach($pattern in @('(?im)^Task ID:\s*ALMT-TASK-007\s*$','(?im)^Status:\s*(PROPOSED|READY)\s*$','(?im)^Experiment Type:\s*ALMT_MOSI_BASELINE_SEEDS_1112_1113\s*$','(?im)^Dataset:\s*MOSI_ALIGNED_50\s*$','(?im)^Seeds:\s*1112,1113\s*$','(?im)^Max Epochs:\s*200\s*$','(?im)^Evaluate Test Once Per Seed:\s*true\s*$')){if($body -notmatch $pattern){throw "Missing contract: $pattern"}}
if((Get-FileHash $config -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configHash){throw 'Config hash mismatch.'}

function Get-SourceHash {
    $paths=@('train.py','core/dataset.py','core/utils.py','models/almt.py','models/almt_layer.py','models/bert.py')
    $sha=[Security.Cryptography.SHA256]::Create();$stream=New-Object IO.MemoryStream
    foreach($path in $paths){$name=[Text.Encoding]::UTF8.GetBytes($path);$stream.Write($name,0,$name.Length);$hex=(Get-FileHash $path -Algorithm SHA256).Hash;$bytes=for($i=0;$i -lt $hex.Length;$i+=2){[Convert]::ToByte($hex.Substring($i,2),16)};$stream.Write($bytes,0,$bytes.Length)}
    $stream.Position=0;return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
}

function Parse-Metrics([string]$line){
    $out=[ordered]@{};foreach($key in @('Has0_acc_2','Has0_F1_score','Non0_acc_2','Non0_F1_score','Mult_acc_5','Mult_acc_7','MAE','Corr')){if($line -notmatch "'$key': (?:np\.float(?:32|64)\()?([-0-9.]+)"){throw "Missing metric $key"};$out[$key]=[double]$matches[1]};return $out
}

Push-Location $repo
try {
    if((git branch --show-current) -ne 'master' -or @(git status --porcelain=v1 --untracked-files=all).Count){throw 'Local master must be clean.'}
    if((Get-SourceHash) -ne $sourceHash){throw 'Frozen training source hash mismatch.'}
    $used=[int]((& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits|Select-Object -First 1).Trim());if($used -gt 1500){throw "GPU occupied: $used MiB"}
    $dir=Join-Path $repo 'ckpt\ALMT_MOSI_baseline_seed1111_r2';[IO.Directory]::CreateDirectory($dir)|Out-Null
    $logDir=Join-Path $repo 'log\runner';[IO.Directory]::CreateDirectory($logDir)|Out-Null
    $records=@()
    foreach($seed in 1112,1113){
        $last=Join-Path $dir "last_seed$seed.pth";$best=Join-Path $dir "best_valid_seed$seed.pth";$audit=Join-Path $dir "audit_seed$seed.json"
        $attempt=Join-Path $dir "test_attempt_seed$seed.json";$done=Join-Path $dir "formal_completion_seed$seed.json";$log=Join-Path $logDir "ALMT-TASK-007-seed$seed.log"
        if(Test-Path $done){$completion=Get-Content $done -Raw|ConvertFrom-Json;$records+=,$completion;continue}
        if(Test-Path $attempt){throw "Seed $seed has an unfinished Test attempt; refusing duplicate Test access."}
        $args=@('train.py','--config_file',$config,'--seed',"$seed",'--gpu_id','0');if(Test-Path $last){$args+=@('--resume','auto')}
        $start=[DateTimeOffset]::UtcNow;& $python @args 2>&1|Tee-Object -FilePath $log -Append;if($LASTEXITCODE){throw "Seed $seed training failed."}
        foreach($p in @($last,$best,$audit)){if(-not(Test-Path $p)){throw "Missing artifact: $p"}}
        $epoch=& $python -c "import torch; print(torch.load(r'$last',map_location='cpu',weights_only=False)['epoch'])";if([int]$epoch -ne 200){throw "Seed $seed did not reach epoch 200."}
        [IO.File]::WriteAllText($attempt,(@{seed=$seed;started_utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
        & $python train.py --config_file $config --seed $seed --gpu_id 0 --resume auto --evaluate_test 2>&1|Tee-Object -FilePath $log -Append;if($LASTEXITCODE){throw "Seed $seed Test attempt failed; it will not be repeated automatically."}
        $test=(Select-String $log -Pattern '^Final Test Results ' | Select-Object -Last 1).Line;$metrics=Parse-Metrics $test
        $bestEpoch=if($test -match 'best Valid epoch ([0-9]+)'){[int]$matches[1]}else{throw 'Best epoch missing.'}
        $peaks=@(Select-String $log -Pattern '^Epoch audit:'|ForEach-Object{if($_.Line -match 'peak_cuda_allocated_mib=([0-9.]+)'){[double]$matches[1]}})
        $completion=[ordered]@{seed=$seed;source_hash=$sourceHash;config_hash=$configHash;best_epoch=$bestEpoch;metrics=$metrics;peak_cuda_allocated_mib=($peaks|Measure-Object -Maximum).Maximum;started_utc=$start.ToString('o');finished_utc=[DateTimeOffset]::UtcNow.ToString('o')}
        [IO.File]::WriteAllText($done,($completion|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false));$records+=,[pscustomobject]$completion
    }
    $seed1111=[ordered]@{seed=1111;best_epoch=40;metrics=[ordered]@{Has0_acc_2=.8222;Has0_F1_score=.8213;Non0_acc_2=.8384;Non0_F1_score=.8381;Mult_acc_5=.4927;Mult_acc_7=.4402;MAE=.7326;Corr=.7894};peak_cuda_allocated_mib=2151.02}
    $all=@([pscustomobject]$seed1111)+$records;$keys=@($seed1111.metrics.Keys);$summary=[ordered]@{}
    foreach($key in $keys){$values=@($all|ForEach-Object{[double]$_.metrics.$key});$mean=($values|Measure-Object -Average).Average;$sum=0.0;foreach($v in $values){$sum+=[Math]::Pow($v-$mean,2)};$summary[$key]=[ordered]@{mean=$mean;sample_std=[Math]::Sqrt($sum/($values.Count-1))}}
    $rows=$all|ForEach-Object{"| $($_.seed) | $($_.best_epoch) | $($_.metrics.MAE) | $($_.metrics.Corr) | $($_.metrics.Has0_acc_2) | $($_.metrics.Has0_F1_score) | $($_.metrics.Non0_acc_2) | $($_.metrics.Non0_F1_score) | $($_.metrics.Mult_acc_5) | $($_.metrics.Mult_acc_7) |"}
    $summaryRows=$keys|ForEach-Object{"| $_ | $($summary[$_].mean) | $($summary[$_].sample_std) |"}
    $report="# EXP-003`n`nStatus: PRELIMINARY`nExperiment Type: FORMAL_BASELINE_THREE_SEED`nTask ID: ALMT-TASK-007`nSource Issue: #$($event.issue.number)`nSource Hash: $sourceHash`nConfig SHA256: $configHash`n`n## Goal`n`nComplete the frozen ALMT MOSI aligned three-seed baseline.`n`n## Protocol`n`nIdentical to EXP-002: fixed 200 epochs, physical/effective batch 4/64, Valid MAE checkpoint selection, and Test evaluated at most once per new seed.`n`n## Results`n`n| Seed | Best epoch | MAE | Corr | Has0 Acc-2 | Has0 F1 | Non0 Acc-2 | Non0 F1 | Acc-5 | Acc-7 |`n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|`n$($rows -join "`n")`n`n| Metric | Mean | Sample std |`n|---|---:|---:|`n$($summaryRows -join "`n")`n`n## Conclusion`n`nPRELIMINARY until Work reviews the complete three-seed evidence. No innovation claim is made.`n"
    [IO.Directory]::CreateDirectory((Split-Path $ReportPath -Parent))|Out-Null;[IO.File]::WriteAllText($ReportPath,$report,[Text.UTF8Encoding]::new($false))
} finally {Pop-Location}
