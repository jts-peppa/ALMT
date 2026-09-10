# Project Status

Last updated: 2026-09-10

- Repository: `E:\ALMT`
- Branch: `codex/almt-gpu-smoke-17` (PR #19)
- Experiment source commit: `fadfda4d7a2e9902790f11cebf800393046ac476`
- Python: `3.11.10`
- Interpreter: `D:\Users\123\anaconda3\envs\ALMT\python.exe`
- PyTorch: `2.5.1+cu121`
- Transformers: `4.49.0`
- CUDA available: `True`
- GPU: `NVIDIA GeForce GTX 1660 Ti`
- MOSI aligned dataset: present at `E:\rc-dlf\dataset\MOSI\Processed\aligned_50.pkl`
- Dataset size: `367257274` bytes
- Baseline status: EXP-001 one-epoch GPU pipeline smoke passed; formal ALMT baseline reproduction has not started and is not confirmed.
- Working directory clean at EXP-001 launch: `Yes`
- Current experiment code changes: none; PR #19 contains documentation only
- Local runtime configuration: `configs/mosi_runner_smoke_local.yaml`, intentionally ignored; SHA-256 recorded in EXP-001
- Current untracked large artifacts: checkpoints under `ckpt/`; logs under `log/`
- Main blocker: EXP-001 requires Work re-review after its audit documentation is updated; formal baseline training remains unauthorized.
- Task handoff file: `docs/agent/NEXT_TASK.md`
- Current task status: `ALMT-TASK-004` completed at the runner level; PR #19 review changes requested
- Next step: re-review PR #19; do not start baseline training or modify model algorithms.

Unknown or intentionally not asserted:

- Peak VRAM of a completed formal baseline run: `UNKNOWN`
- Final reproduced ALMT metrics: `UNKNOWN`
- Final innovation direction: `UNKNOWN`

## Latest Automated Baseline

- Experiment: EXP-002
- Dataset: MOSI aligned
- Seed: 1111
- Status: PRELIMINARY pending Work review
- Report: docs/agent/runs/exp-002.md

