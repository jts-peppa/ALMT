# Next Codex Task

Task ID: ALMT-TASK-003
Status: IN_PROGRESS
Source Experiment: NONE
Source Issue: #12

## Claim Information

Owner: self-hosted-r0
Working Branch: codex/almt-task-12-r0
Claimed At: 2026-09-09T08:33:36Z

## Approved Specification

Task ID: ALMT-TASK-003
Status: PROPOSED
Source Experiment: NONE

## Goal
Verify that the restricted R0 workflow emits ready_for_review after all handoff records complete.

## Hypothesis
The workflow creates a Draft PR, completes its records, and then transitions that PR to Ready.

## Files Allowed to Modify
- docs/agent/NEXT_TASK.md
- docs/agent/runs/ALMT-TASK-003-R0.md

## Files Not Allowed to Modify
- Every file outside docs/agent/

## Implementation Requirements
Record receipt only. Do not invent experiment evidence.

## Experiment Configuration
No experiment and no training.

## Seeds
None.

## Metrics
Workflow completion and ready_for_review event.

## Validation Strategy
Require the docs/agent path guard and inspect the PR timeline event.

## Acceptance Criteria
A docs-only Draft PR is created and then marked Ready.

## Required Report
docs/agent/runs/ALMT-TASK-003-R0.md

## Git Requirements
The trusted workflow creates the branch, Draft PR, and Ready transition.

## R0 Boundary

This is a documentation-only handoff test. The trusted workflow, not Codex, performs Git operations. No experiment or training is authorized.