# Next Codex Task

Task ID: `UNASSIGNED`
Status: `EMPTY`
Source Experiment: `NONE`
Source Issue: `NONE`

## State Contract

Allowed status values:

- `EMPTY`: no task is assigned.
- `READY`: ChatGPT has prepared a complete task for Codex.
- `IN_PROGRESS`: Codex has claimed the task and recorded its working branch.
- `BLOCKED`: Codex cannot continue without a documented decision or external dependency.
- `COMPLETED`: implementation, verification, reporting, commit, and push are complete.
- `REJECTED`: the task was rejected with recorded evidence and no implementation should continue.

ChatGPT Work may propose a task in a structured GitHub Issue. A human project owner must add the exact `approved` label. Codex may then claim the task, copy the specification into this file, and change the repository state to `IN_PROGRESS`. Codex must not broaden the scope or rewrite acceptance criteria after seeing evaluation results.

## Claim Information

Owner: `NONE`
Working Branch: `NONE`
Claimed At: `UNKNOWN`

Codex must change `READY` to `IN_PROGRESS` and record the working branch before modifying task files. If the task is already `IN_PROGRESS`, a second Agent must not modify that branch.

## Goal

No task assigned.

## Hypothesis

Not applicable.

## Files Allowed to Modify

None.

## Files Not Allowed to Modify

All project files until a task is assigned.

## Experiment

No experiment assigned.

## Metrics

Not applicable.

## Acceptance Criteria

Not applicable.

## Required Output

When a real task is assigned, this section must name the required report under `docs/agent/runs/` and any required status/index updates.

## Execution Rules

1. If `Status` is not `READY` or `IN_PROGRESS`, Codex must not start new implementation or training from this file.
2. A new task may enter this file only from one structured GitHub Task Issue carrying the exact human-applied `approved` label.
3. Codex must execute only the stated goal and allowed files.
4. Dataset splits, metrics, seeds, thresholds, and acceptance criteria must be fixed before evaluation.
5. Test must not be used for iterative development or hyperparameter selection.
6. Every formal experiment must use a new monotonically increasing experiment ID.
7. On completion, update the experiment report, `EXPERIMENTS.md`, `STATUS.md`, and this task status.
8. Commit and push only reviewable source, configuration, and small reports; never commit datasets, weights, caches, raw logs, secrets, or environment directories.
