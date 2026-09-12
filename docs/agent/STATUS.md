# Project Status

Last updated: 2026-09-11

- Repository: `E:\ALMT`
- Branch: `codex/almt-baseline-seed1111-r2` (PR #24)
- Experiment source commit: `bc8ae135bba392f046f0b4f27424c1248327dbf4`
- Python: `3.11.10`
- Interpreter: `D:\Users\123\anaconda3\envs\ALMT\python.exe`
- PyTorch: `2.5.1+cu121`
- Transformers: `4.49.0`
- CUDA available: `True`
- GPU: `NVIDIA GeForce GTX 1660 Ti`
- MOSI aligned dataset: present at `E:\rc-dlf\dataset\MOSI\Processed\aligned_50.pkl`
- Dataset size: `367257274` bytes
- Baseline status: EXP-002 completed one formal Seed 1111 baseline on MOSI aligned features; status is PRELIMINARY pending Work review.
- Working directory clean at EXP-002 launch: `Yes`
- Current experiment code changes: none; PR #24 contains documentation and audit evidence only
- Local runtime configuration: `configs/mosi_runner_smoke_local.yaml`, intentionally ignored; SHA-256 recorded in EXP-002
- Current untracked large artifacts: checkpoints under `ckpt/`; logs under `log/`
- Main blocker: EXP-002 requires Work review before it can be treated as accepted project evidence.
- Task handoff file: `docs/agent/NEXT_TASK.md`
- Current task status: `ALMT-TASK-005` completed at the runner level; EXP-002 documentation repair prepared under `ALMT-TASK-006`
- Next step: review the EXP-002 documentation repair; do not rerun training, inference, Test, or modify model algorithms.

Known formal baseline result:

- Experiment: EXP-002
- Dataset: MOSI aligned
- Seed: 1111
- Status: PRELIMINARY pending Work review
- Report: docs/agent/runs/exp-002.md
- Final Test Results (explicit request, best Valid epoch 40): {'Has0_acc_2': 0.8222, 'Has0_F1_score': 0.8213, 'Non0_acc_2': 0.8384, 'Non0_F1_score': 0.8381, 'Mult_acc_5': np.float64(0.4927), 'Mult_acc_7': np.float64(0.4402), 'MAE': np.float32(0.7326), 'Corr': np.float64(0.7894)}
- Total run seconds: 8968.31
- Peak CUDA allocated MiB across logged epochs: 2151.02

Unknown or intentionally not asserted:

- Multi-seed baseline stability: `UNKNOWN`
- Final innovation direction: `UNKNOWN`

## Latest Automated Baseline

- Experiment: EXP-003
- Dataset: MOSI aligned
- Seeds: 1111, 1112, 1113
- Status: PRELIMINARY pending Work review
- Report: docs/agent/runs/exp-003.md
