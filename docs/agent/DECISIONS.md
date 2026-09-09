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

## DEC-003 Use a Versioned Task Handoff

Date: 2026-09-09
Status: Accepted

### Context

Separate ChatGPT and Codex conversations do not provide a dependable shared conversation history. A task must remain available across sessions and be reviewable before implementation begins.

### Decision

Use `docs/agent/NEXT_TASK.md` as the unique versioned task handoff for the repository. A task may be implemented only when its status is `READY`. Codex must claim it as `IN_PROGRESS` on a dedicated branch before modifying scoped files.

### Reason

A committed handoff makes the goal, permitted files, experiment protocol, acceptance criteria, and required outputs visible to both Agents while preventing simultaneous modification of one branch.

### Evidence

The project owner selected GitHub as the shared state and requested a repository-based ChatGPT-to-Codex handoff on 2026-09-09.

### Consequence

Chat messages alone do not authorize cross-session experimental work. The assigned task, implementation branch, reports, and completion status must be represented in Git. GitHub Issues or PR comments may supplement the handoff, but they do not silently override the committed task scope.

## DEC-004 Require Human Approval for Agent Tasks

Date: 2026-09-09
Status: Accepted

### Context

A fully automatic review-to-experiment loop could consume GPU time, alter protocols, or create multiple concurrent tasks without the project owner noticing.

### Decision

ChatGPT Work creates one structured Task Issue with status `PROPOSED`. Codex may claim it only after the human project owner applies the exact `approved` label. After claim, the committed `NEXT_TASK.md` becomes authoritative.

### Reason

The Issue transports the full task without manual prompt copying, while the approval label preserves human control over research cost and direction. The committed claim prevents simultaneous branch ownership.

### Evidence

The project owner selected the Issue-to-claim workflow and requested an explicit human approval gate on 2026-09-09.

### Consequence

ChatGPT Work must not approve its own Issue. Codex must fail closed on zero or multiple eligible tasks and must not execute an unapproved proposal.
