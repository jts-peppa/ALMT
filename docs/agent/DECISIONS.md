# Research Decisions

## DEC-001 Establish Git-Based Agent Collaboration

Date: 2026-09-09
Status: Accepted

### Context

The project will be developed by a research-decision Agent and an implementation Agent. A shared, auditable state is required to prevent conflicting edits and undocumented experiments.

### Decision

Use GitHub as the shared project state. ChatGPT is responsible for literature analysis, experiment interpretation, research decisions, and task design. Codex is responsible for implementation, commands, tests, experiments, commits, and pushes. The two Agents must not modify the same working branch concurrently.

### Reason

Separating responsibilities and recording work in Git makes code changes, experimental assumptions, and decisions reviewable and reproducible.

### Evidence

This responsibility split and branch-safety rule were explicitly accepted in the project bootstrap request dated 2026-09-09.

### Consequence

Future implementation work must use an assigned branch and communicate state through commits and files under `docs/agent/`. Research conclusions require recorded experimental evidence.

## DEC-002 Protect Evaluation Integrity

Date: 2026-09-09
Status: Accepted

### Context

Repeated Test evaluation can leak information into model and hyperparameter selection.

### Decision

Use Valid for method selection. Do not use Test for repeated tuning. Evaluate Test only after the method and protocol are frozen.

### Reason

This preserves a meaningful final evaluation and prevents optimistic reporting caused by iterative Test feedback.

### Evidence

The evaluation rule was explicitly included in the project bootstrap requirements dated 2026-09-09.

### Consequence

Every experiment report must identify the splits used, and training code must not silently evaluate Test during model selection.
