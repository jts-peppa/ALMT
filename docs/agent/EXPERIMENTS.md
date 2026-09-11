# Experiment Index

| ID | Date | Branch | Commit | Goal | Dataset | Seed | Status | Result |
|---|---|---|---|---|---|---|---|---|
| EXP-002 | 2026-09-10 | `codex/almt-baseline-seed1111-r2` | `bc8ae135bba392f046f0b4f27424c1248327dbf4` | Reproduce the frozen ALMT MOSI aligned baseline | MOSI aligned | 1111 | PRELIMINARY | One-seed formal baseline; see exp-002.md |
| EXP-001 | 2026-09-10 | `codex/almt-gpu-smoke-17` | `fadfda4d7a2e9902790f11cebf800393046ac476` | Validate the approved Issue-to-local-GPU one-epoch pipeline without Test access | MOSI aligned | 1111 | PRELIMINARY | Infrastructure smoke passed; no scientific metrics or baseline claim |

Each formal experiment must create a new report:

`docs/agent/runs/exp-XXX.md`

Experiment identifiers must increase monotonically and existing reports must never be overwritten. Smoke tests and diagnostics must be clearly distinguished from formal experiments. An entry is added only after a real experiment has been defined or run; this bootstrap does not create historical experiment claims.
