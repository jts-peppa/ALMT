# Codex Task Intake Protocol

## Authoritative Flow

```text
ChatGPT Work review
    -> one ALMT-TASK issue with Status: PROPOSED
    -> human applies the exact `approved` label
    -> Codex claims the task on a unique branch
    -> Codex commits NEXT_TASK.md with Status: IN_PROGRESS
    -> implementation, tests, and permitted experiments
    -> reports and indexes updated
    -> implementation branch pushed and PR marked ready
    -> ChatGPT Work review
```

GitHub Issue is the transport channel. After Codex claims an approved task, `docs/agent/NEXT_TASK.md` is the authoritative execution scope.

## R0 Self-Hosted Runner Boundary

The initial automation stage is deliberately documentation-only. An Issue event may launch Codex only when all of the following are true:

- repository is exactly `jts-peppa/ALMT`;
- Issue creator and label actor are exactly `jts-peppa`;
- the applied label is exactly `approved`;
- the title matches `[ALMT-TASK-NNN] <goal>`;
- the body contains `Status: PROPOSED` or `Status: READY`;
- `NEXT_TASK.md` is not already `IN_PROGRESS`;
- the dedicated runner has the `almt-local` label.

R0 runs Codex read-only and requires a schema-validated `ACCEPT` or `REJECT` decision. After acceptance, a trusted script writes only `NEXT_TASK.md` and the task's R0 handoff report. A post-run path guard rejects every other changed path before commit. R0 must not train a model, access datasets, use the GPU, modify algorithms, or execute commands copied from Issue text. Opening source-code or GPU permissions requires a separately reviewed later-stage workflow.

The trusted workflow first opens a Draft PR. Only after the required handoff record and Issue comment succeed does it mark that PR ready through GitHub's `markPullRequestReadyForReview` mutation. This transition must emit `ready_for_review`, which is the review Agent's trigger; creating a non-draft PR directly is not permitted.

## R1 GPU Smoke Boundary

GPU execution requires both `approved` and `gpu-approved`; the owner must apply `gpu-approved` last to trigger the workflow. R1 accepts exactly one open task carrying both labels and supports only the fixed `ALMT_MOSI_BASELINE_SMOKE_R1` contract: MOSI, Seed 1111, one epoch, and no Test evaluation. It verifies the full source commit, local configuration SHA-256, clean `master` checkout, approved interpreter, and available GPU before starting. R1 produces a small report PR through the same Draft-to-Ready sequence and cannot authorize a full baseline run.

## R1 GPU Smoke Boundary

The first GPU-capable workflow is limited to a single MOSI epoch with Seed 1111 and Test evaluation disabled. It requires both `approved` and `gpu-approved`, with `gpu-approved` applied by `jts-peppa`. The task body must contain the fixed experiment type, source commit, configuration SHA-256, seed, epoch limit, and Test prohibition. The local checkout must be clean, on the exact approved commit, and use no more than 1500 MiB of GPU memory before launch. Only a small smoke report may be committed; checkpoints and full logs remain local and ignored. Full training is not authorized by R1.

## Fixed Codex Intake Procedure

1. Fetch the current repository and inspect open issues whose title begins with `[ALMT-TASK-`.
2. Consider only issues containing the exact `approved` label and a body status of `PROPOSED` or `READY`.
3. If no eligible task exists, stop without creating a research task.
4. If multiple eligible tasks exist, stop and report the conflict; do not choose one.
5. If `docs/agent/NEXT_TASK.md` is already `IN_PROGRESS`, stop and report the existing task and branch.
6. Validate that the issue has a unique Task ID, one research question, an immutable experiment protocol, allowed files, forbidden files, metrics, acceptance criteria, and a required report.
7. Pull the agreed base branch and verify the source commit. Stop on conflicts or an unexpected dirty working tree.
8. Create exactly one unique branch named from the Task ID using the `codex/` prefix.
9. Copy the approved issue specification into `docs/agent/NEXT_TASK.md`, set it to `IN_PROGRESS`, and record the issue number, owner, branch, source commit, and claim time.
10. Commit and push the claim before modifying implementation files.
11. Execute only the committed task scope. Do not change seeds, splits, metrics, thresholds, or acceptance criteria after evaluation begins.
12. On completion, update the required run report, `EXPERIMENTS.md`, `STATUS.md`, and `NEXT_TASK.md`; then commit and push the implementation.
13. Create or update one PR. Mark it ready for review only after all required tests, reports, hashes, and audits are complete.

## Fail-Closed Conditions

Codex must stop without implementation when:

- the issue lacks the exact `approved` label;
- more than one approved task is eligible;
- another task or branch is already active;
- the issue changes after the claim commit;
- the source commit, dataset contract, or working tree is inconsistent;
- the task requires Test-driven tuning, undisclosed files, or unapproved expansion;
- required authority, credentials, data, hardware, or disk capacity is unavailable.

## Research Safety

- A human approval label authorizes the scoped task, not arbitrary follow-on experiments.
- Long GPU runs, Test evaluation, destructive cleanup, and material protocol changes require any additional approval explicitly stated in the task.
- ChatGPT Work may propose the next task and review evidence, but it must not execute code, merge PRs, or approve its own task.
- GitHub comments and chat messages may clarify a task but do not override the committed `NEXT_TASK.md` scope.
