# Project implementation retrospective: FPGA tutorial process effectiveness

- Case ID: 2026-10-18-fpga-tutorial-process-effectiveness
- Created / last supplemented: 2026-10-18 / 2026-10-18
- Environment: runtime/customer experiment workspace; Windows 10.0.26200.0 (current diagnostic host observation)
- SDK version / Adapter version / toolchain version: exported conversation reports catalog v0.9.6, Icarus Verilog 12.0, and Efinity 2026.1; adapter version unknown
- Project revision: `3be0d208135508d2015017b23b724abdd79d91c9`; pre-existing untracked control requests, `design-packages/segcount-v1/`, and `worktree_test/` were present and were not modified
- Requirement and outcome sources: external conversation export alias `conversation-export` = `C:\Users\dylan Wang\Desktop\Evoverse FPGA 全流程教程.md` (SHA-256 `F4384C283A477DE8C7A8201D759A804806A54F49284DDD20E64F83506019D109`); user supplement in the current chat

## Goals and actual results

Expected: use a simple pure-RTL design to demonstrate one coherent lifecycle—environment setup, one project creation, baseline intent, natural-language generation, verification, native build, programming/hardware validation, two increments, system integration, and a clear tutorial site.

Actual: the conversation reports successful simulations and native builds, a tutorial site, and later visual/interaction improvements. Hardware validation remained `NOT_RUN`. More importantly, the workflow never stabilized its central lifecycle invariant: project creation happens once; later intents evolve and integrate into that project. The contradiction survived replay and completion reporting until the user identified it near the end (`conversation-export:1700`).

## Overall process and phenomena

| Stage | What was done | Observed phenomena / manual interventions | Outcome and source |
|---|---|---|---|
| Design | Proposed 12-chapter story and real execution | Correct high-level split: chapter 03 creates project, chapter 06 compiles | agreed (`conversation-export:42`) |
| Baseline | Created specifications, RTL, simulation candidate, promotion and native build | Schema/root/path rules discovered by sequential failures; promoted simulation baseline later failed synthesis | assistant-reported PASS after repair (`conversation-export:130-197`, `306-314`) |
| Parallel increments | Created seg-counter and btn-switch intents | Specification resolver selected latest approved package; worktree/whitelist rules forced serial workarounds and repeated cleanup | assistant-reported simulation PASS and queued integrations (`conversation-export:382-458`) |
| Tutorial replay | Replayed tutorial in a clean project | Copied verified files instead of exercising natural-language generation; copy method introduced BOM and a long repair chain | replay did not validate requested generation step (`conversation-export:611`, `661-713`) |
| Integration | Manually integrated and rebuilt | No control-plane queue-consumption action was found; build registration followed manual Git integration | assistant-reported build PASS, hardware NOT_RUN (`conversation-export:975-1096`) |
| Site redesign | Converted content to main-flow/right-rail layout | Three subagent result groups were lost/not written and had to be redispatched | ultimately reported complete (`conversation-export:1236`, `1370-1394`, `1567`) |
| Final semantic review | User inspected experiment sequence | Found chapter 06 regenerated an already-existing project; ten edits were required after prior full-completion claims | corrected (`conversation-export:1700-1773`) |

## Key artifacts and evidence

| Evidence ID | Original artifact or log path | Version / input linkage | Error summary or supported fact | Reference location | Snapshot path / SHA-256 | Collection time / source stability / copy type | Status |
|---|---|---|---|---|---|---|---|
| EV-PROC-1 | external alias `conversation-export` | complete supplied dialogue export | 24 human turns; repeated retries, completion claims, and final lifecycle correction | lines 1-1776 | external only / `F4384C283A477DE8C7A8201D759A804806A54F49284DDD20E64F83506019D109` | supplied 2026-10-18 / external file / raw | present, not copied |
| EV-PROC-2 | `.evoverse/control/requests/` | current project state | pre-existing untracked requests indicate control activity, but were not used as historical transcript evidence | current `git status` | not snapshotted | 2026-10-18 / mutable | present |
| EV-PROC-3 | `project-review/2026-10-17-marquee-lab-compile-baseline/review.md` | prior compile-only case | compile baseline evidence does not cover the full tutorial-process failure | existing review | existing project file | 2026-10-18 / project file | present |

## How far validation reached

- Natural-language generation: not validated by the clean replay; the replay copied known-good files (`conversation-export:661`).
- Simulation: multiple PASS results are narrated, but this review did not receive raw originating tool outputs.
- Build: native Efinity map/interface/pnr/pgm PASS is narrated; the separate compile-baseline review retains selected build evidence.
- Programming: attempted/unavailable in the narrated flow; no programming PASS.
- Hardware: `NOT_RUN`; board was not connected (`conversation-export:1096`, `1138`).
- Visual QA: layout geometry and console checks were performed, but screenshots could not be read and narrow-screen behavior was checked statically (`conversation-export:1555-1561`).

## Project assembly and reuse

- Assembly manifest / preflight receipt: unknown for the whole tutorial case.
- Asset ownership: catalog baseline reused; generated-vs-copied ownership became blurred during replay.
- IP VLNV, normalized parameters, generation or reuse receipts: no IP evidence reviewed.
- Cache hits and reasons for misses: unknown.
- Efinity version and native flow: Efinity 2026.1; narrated unified compile map/interface/pnr/pgm.
- Were flow-assist Python/batch tools produced: a temporary batch was narrated for environment sharing and later deleted; no persistent workaround tool was reviewed.

## Problems and improvement candidates

| Candidate ID | Expected / phenomenon / impact | Evidence ID | Root-cause hypothesis (mark if unconfirmed) | Suggested investigation or improvement | Scope |
|---|---|---|---|---|---|
| C-1 | One project should be created once and evolved; tutorial regenerated it later | EV-PROC-1 | Confirmed process-model omission: lifecycle invariant was not an acceptance criterion | Make project lifecycle (`NEW_PROJECT → BASELINE → INCREMENT → SYSTEM_INTEGRATION`) an explicit server-owned state shown in every next-action response; reject generation actions once the project exists unless a new-project intent is explicit | SDK/control plane |
| C-2 | Actions should be invoked from stable contracts; fields, roots and prerequisites were discovered by failure | EV-PROC-1 | Confirmed observation; exact implementation cause not reviewed | Return complete machine-readable input schema, path base, cleanliness preconditions, and one valid example with `project.next`; add a preflight-only validation path | SDK/control plane |
| C-3 | Parallel intents should remain independently resolvable | EV-PROC-1 | Confirmed observed behavior: latest-approved resolution serialized work; root cause implementation not reviewed | Bind spec lookup to `intentId + specPackageDigest + absolute runRoot`, never to global latest-approved state | SDK reliable flow |
| C-4 | A replay claiming natural generation should generate, not copy | EV-PROC-1 | Confirmed acceptance mismatch | Define replay assertions for provenance: generated files must carry the current request/intent/digest receipt; copied fixtures may test later stages but cannot satisfy generation coverage | SDK evaluation/tutorial QA |
| C-5 | Completion should mean all promised boundaries were checked | EV-PROC-1 | Confirmed reporting gap | Gate “complete” on a small acceptance matrix: lifecycle semantics, generation provenance, simulation, build, programming, hardware, and visual QA; allow `NOT_RUN` but prohibit “全流程全绿” when a promised stage is not run | SDK/agent guidance |
| C-6 | Parallel page work should not disappear | EV-PROC-1 | Confirmed missing persistence; mechanism unknown | Require each delegated task to return a write receipt (paths + hashes) and verify it before marking the task complete or redispatching | agent workflow |
| C-7 | Known constraints should survive phase changes | EV-PROC-1 | Confirmed repeated rediscovery | Persist a compact iteration state package containing validated schemas, path roots, encoding, source-closure rules, worktree whitelist, and prior failure signatures; reload it before each action instead of searching again | SDK/agent workflow |

## Project lessons and SDK feedback

Project-specific lessons:

- Freeze the tutorial's state machine before writing code or pages. The central invariant is more important than the number of individual PASS receipts.
- Separate “real design generation” from “fixture reuse.” They prove different things.
- Treat simulation, native build, programming, hardware, and visual inspection as distinct evidence boundaries.
- Do not call a tutorial complete until a fresh reader can follow its project-state transitions without contradiction.

Candidates transferable to the SDK: C-1 through C-7. The highest-leverage items are C-1 (explicit lifecycle state), C-2 (complete action contracts), C-3 (intent-bound specification identity), and C-5 (completion matrix).

Development intake location and status: not consolidated; this review records candidates only and does not modify SDK source or release artifacts.

## Material gaps and later follow-ups

- Exact wall-clock time, token use, raw tool calls/results, model/harness version, compactions, and child-agent transcripts are unavailable in the supplied export.
- The export is assistant narrative, not raw execution evidence. Claims of PASS remain reported claims unless supported by retained project evidence.
- Physical board programming and hardware behavior remain unverified.
- No SDK fix was implemented in this task. Each improvement candidate needs separate reproduction, design approval, implementation, and validation.

<!-- evoverse-project-review:evidence
{"hardwareStatus":"NOT_RUN","evidence":[]}
-->
