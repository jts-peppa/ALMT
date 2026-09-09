# Next Codex Task

Task ID: ALMT-TASK-001
Status: IN_PROGRESS
Source Experiment: NONE
Source Issue: #7

## Claim Information

Owner: self-hosted-r0
Working Branch: codex/almt-task-7-r0
Claimed At: 2026-09-09T08:15:17Z

## Approved Specification

Task ID: ALMT-TASK-001
Status: PROPOSED
Source Experiment: NONE

## Goal
Verify the complete documentation-only self-hosted Runner to Codex handoff after enabling PR creation.

## Hypothesis
One approved Issue should produce one reviewable docs/agent-only pull request without training or algorithm changes.

## Files Allowed to Modify
- docs/agent/NEXT_TASK.md
- docs/agent/runs/ALMT-TASK-001-R0.md

## Files Not Allowed to Modify
- Every file outside docs/agent/

## Implementation Requirements
Record receipt of this R0 task. Do not invent experiment evidence.

## Experiment Configuration
No experiment and no training.

## Seeds
None.

## Metrics
Workflow completion only.

## Validation Strategy
The Runner post-run path guard must accept only docs/agent changes.

## Acceptance Criteria
A pull request is opened containing only docs/agent changes.

## Required Report
docs/agent/runs/ALMT-TASK-001-R0.md

## Git Requirements
The trusted workflow creates one branch and one pull request.

## R0 Boundary

This is a documentation-only handoff test. The trusted workflow, not Codex, performs Git operations. No experiment or training is authorized.