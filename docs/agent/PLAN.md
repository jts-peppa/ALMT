# Research Plan

## Research Goal

围绕多模态情感分析寻找可发表的创新点，通过 baseline 复现、问题诊断、创新设计和严格实验逐步验证。

## Responsibilities

- 网页版 ChatGPT：负责论文分析、实验分析、研究决策和下一步任务设计。
- Codex：负责代码修改、命令执行、测试、实验、Git 提交和推送。
- GitHub：作为两个 Agent 之间的共享状态和实验记录。
- 不允许两个 Agent 同时修改同一个工作分支。

## Working Principles

1. 先复现 baseline。
2. 不因为单次 seed 的结果就判断创新有效。
3. 优先进行低成本可行性实验。
4. Valid 用于方案筛选，Test 不用于反复调参。
5. 候选创新只有在多 seed 下表现稳定后才进入正式实验。
6. 所有实验必须能够通过 Git commit、配置和报告复现。
7. 不允许为了得到更好结果偷偷改变数据划分或评价指标。
8. 网页版 ChatGPT 负责研究决策，Codex 负责实现与验证。

## Workflow

1. 冻结并复现 baseline。
2. 记录数据、代码、配置、环境和评价协议。
3. 进行低成本问题诊断和可行性实验。
4. 由 ChatGPT 审查证据并决定候选创新是否继续。
5. 通过后进行多 seed 正式实验和消融。
6. 方法完全冻结后才进行最终 Test 评价。

