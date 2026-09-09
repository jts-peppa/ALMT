---
name: ALMT research task
about: Propose one reviewable ChatGPT-to-Codex research task
title: "[ALMT-TASK-XXX] "
labels: []
assignees: []
---

Task ID: `ALMT-TASK-XXX`
Status: `PROPOSED`
Source PR: `NONE`
Source Experiment: `NONE`
Source Commit: `UNKNOWN`

## Goal

## Hypothesis

## Files Allowed to Modify

## Files Not Allowed to Modify

## Implementation Requirements

## Experiment Configuration

Dataset:

## Seeds

## Metrics

## Validation Strategy

## Acceptance Criteria

## Required Report

`docs/agent/runs/exp-XXX.md`

## Git Requirements

- Create one dedicated task branch.
- Do not modify another Agent's active branch.
- Do not commit datasets, weights, caches, raw logs, secrets, or environments.
- Push the implementation branch and create or update one PR.
- Mark the PR ready for review only after implementation, testing, reporting, and audit are complete.

## Approval Gate

Codex must not execute this issue until a human project owner adds the exact GitHub label `approved`. ChatGPT Work must create tasks as `PROPOSED` and must not add that approval label on behalf of the owner.
