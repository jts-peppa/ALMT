# Next Codex Task

Task ID: ALMT-TASK-002
Status: IN_PROGRESS
Source Experiment: NONE
Source Issue: #9

## Claim Information

Owner: self-hosted-r0
Working Branch: codex/almt-task-9-r0
Claimed At: 2026-09-09T08:20:44Z

## Approved Specification

Task ID: ALMT-TASK-002
Status: PROPOSED
Source Experiment: NONE

## Goal
Verify the final documentation-only self-hosted Runner to Codex handoff.

## Hypothesis
One approved Issue produces one docs/agent-only pull request without training or algorithm changes.

## Files Allowed to Modify
- docs/agent/NEXT_TASK.md
- docs/agent/runs/ALMT-TASK-002-R0.md

## Files Not Allowed to Modify
- Every file outside docs/agent/

## Implementation Requirements
Record receipt only. Do not invent experiment evidence.

## Experiment Configuration
No experiment and no training.

## Seeds
None.

## Metrics
Workflow completion only.

## Validation Strategy
Require the post-run docs/agent path guard.

## Acceptance Criteria
A pull request is opened containing only docs/agent changes.

## Required Report
docs/agent/runs/ALMT-TASK-002-R0.md

## Git Requirements
The trusted workflow creates one branch and one pull request.

## R0 Boundary

This is a documentation-only handoff test. The trusted workflow, not Codex, performs Git operations. No experiment or training is authorized.