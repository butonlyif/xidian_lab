# Project implementation retrospective: marquee-lab compile baseline (T20F256)

- Case ID: 2026-10-17-marquee-lab-compile-baseline
- Created / last supplemented: 2026-10-17 / 2026-10-17
- Environment: runtime（客户实验工作区）; Windows, PowerShell 5
- SDK version / Adapter version / toolchain version: Efinity 2026.1（`C:\Efinity\2026.1`，sw_version 2026.1.132.1.15，读取自工程 XML 与 peri.xml）; EvoVerse catalog 0.9.6（commit a13abff，读取自 `.evoverse/catalog.json`）; 仿真工具链未使用
- Project revision: Git root-commit `a9783ba`（2026-10-17，18 文件：工程源 + 证据 + 工作区配置；outflow/work_* 经 .gitignore 排除）。此前无 Git——本条为建仓后补记。
- Requirement and outcome sources: session（用户：t20f256 板上新建 marquee-lab，最简单设计走通编译流程）

## Goals and actual results

目标：在 t20f256-xd-ps-eval 板上以 catalog `marquee` jacket（硬件验证基线）为源，建立名为 `marquee-lab` 的 Efinity 原生工程并完成 unified compile 全流程。
实际结果：工程建于 `marquee-lab/`，map / interface / pnr / pgm 四阶段双连 PASS（引导 + 重放），生成 `outflow/marquee-lab.bit`。仿真、烧录、板级验证未执行（用户未要求；本次目标仅为编译流程）。

## Overall process and phenomena

| Stage | What was done | Observed phenomena / manual interventions | Outcome and source |
|---|---|---|---|
| 基线选取 | 从 catalog `t20f256-xd-ps-eval/jackets/marquee` 拷贝 rtl/constraints/sim/peri.xml，工程改名 marquee-lab | 无 | 完成（文件存在） |
| 首次编译（携带原 peri.xml） | `efx_run --flow compile` | interface FAIL：`GPIO clk_50m_i exists` ×3 + `Bus name is used`（EV-1） | FAIL（run1 log） |
| 诊断 | 读 `efx_run_pt_unified.py` + 检查 `outflow/marquee-lab.unified.isf` | unified flow 中 map netlist 恒定先于用户 ISF 重放，内含 create_*（带 partial-design 锁）；原 peri.xml 的 GPIO 锁引用旧工程名 `.peri.db`，改名后锁源不匹配 → 重复创建报错 | 根因定位（源码+产物证据） |
| 修正尝试 A | 删 peri.xml + 启用 ISF create_* | 仍 FAIL：与 netlist ISF 的自动创建撞车 → 证明 unified flow 中用户 ISF 不应含 create_* | FAIL（未留存日志，现象同 run1） |
| 修正（最终） | 删 peri.xml、create_* 全部注释，让 PT 原生重建 | 首跑由工具生成全新 `marquee-lab.peri.xml`（锁指向 marquee-lab.peri.db）；四阶段 PASS | PASS（run2 log） |
| 重放验收 | 再次 `efx_run --flow compile` | 四阶段 PASS（ISF 纯 pins 风格重放安全） | PASS（run3 log） |
| 产物核验 | 检查 outflow | `marquee-lab.bit`/`.hex` 各 2,035,950 字节；timing 全 MET | present |

## Key artifacts and evidence

| Evidence ID | Original artifact or log path | Version / input linkage | Error summary or supported fact | Reference location | Snapshot path / SHA-256 | Collection time / source stability / copy type | Status |
|---|---|---|---|---|---|---|---|
| EV-1 | marquee-lab/compile_stdout.log | Efinity 2026.1, run1 输入 = jacket peri.xml（旧名锁） | interface FAIL：GPIO exists ×3 / Bus name is used | 全文 18 行 | evidence/run1-fail-peri-replay.log / E4F4E39831C37DF37E3619E34F08A8451CF03558E4C61658BB5F9688CAC4F20C | 2026-10-17 / 下次编译会覆盖 / raw | snapshotted |
| EV-2 | marquee-lab/bootstrap_compile.log | run2（原生重建 peri.xml 后） | map/interface/pnr/pgm 全 PASS | 全文 9 行 | evidence/run2-bootstrap-pass.log / A7DE7DE34A50912C0E3BC25C79EC9BD39861D8F24731593663F778736CDA0281 | 2026-10-17 / 会覆盖 / raw | snapshotted |
| EV-3 | marquee-lab/replay_compile.log | run3（重放） | 四阶段 PASS（stdout 无时间戳，与 EV-2 字节一致；区分凭据：bitstream mtime 20:51:35、peri.xml last_change 20:51:29） | 全文 9 行 | evidence/run3-replay-pass.log / A7DE7DE34A50912C0E3BC25C79EC9BD39861D8F24731593663F778736CDA0281 | 2026-10-17 / 会覆盖 / raw | snapshotted |
| EV-4 | marquee-lab/outflow/marquee-lab.timing.rpt | run3 | clk_50m 20 ns 约束下 Fmax 190.767 MHz；setup slack 14.758 ns、hold slack 0.306 ns，无违例 | L30/L34/L44/L48 | evidence/run3-timing.rpt / 0D7F9C539A0289293AD22573313B1F1A7C1D08AC4894BEDC528B118B27CFECA4 | 2026-10-17 / 下次编译会覆盖 / raw | snapshotted |
| EV-5 | marquee-lab/outflow/marquee-lab.bit | run3 产物 | 比特流 2,035,950 字节（未快照，可再生） | — | — | 未快照 | present |
| EV-6 | marquee-lab/marquee-lab.peri.xml | run2 由 PT 原生产生 | name=marquee-lab，partial_design source=marquee-lab.peri.db（锁一致） | L2/L114 | 未快照（工程源文件随目录留存） | — | present |

## How far validation reached

- 仿真：未执行（jacket 自带 sim/tb_led_marquee.v，本次未跑）。
- Build：unified compile（efx_map → PT(interface) → efx_pnr → efx_pgm）双连 PASS，证据 EV-2/EV-3；时序 MET（EV-4）。
- 烧录：未执行。
- 板级：未执行；jacket 基线本身标注 hardware-validated，但那是基线在其原工程名下的历史验证，不是 marquee-lab 本次的硬件 PASS。

## Project assembly and reuse

- Assembly manifest / preflight receipt: 无（非控制面受管工程，无 `.evoverse/control/project.json`）
- Asset ownership: rtl/constraints/sim 为 reused-verified（catalog jacket 拷贝）；marquee-lab.peri.xml 为 generated-candidate（本次由 Efinity PT 原生重建）；marquee-lab.xml 为 project-owned（改名自 jacket 快照）
- IP VLNV, normalized parameters, generation or reuse receipts: 无 IP
- Cache hits and reasons for misses: 不适用
- Efinity version and native flow: 2026.1（C:\Efinity\2026.1），`efx_run --flow compile marquee-lab.xml`（PowerShell 等价翻译 setup.bat 环境；宿主 shell 禁止 cmd /c）
- Were flow-assist Python/batch tools produced: no

## Problems and improvement candidates

| Candidate ID | Expected / phenomenon / impact | Evidence ID | Root-cause hypothesis (mark if unconfirmed) | Suggested investigation or improvement | Scope |
|---|---|---|---|---|---|
| C-1 | 期望：拷贝含 peri.xml 的 jacket 快照改名后可直接 unified 编译。现象：interface FAIL `GPIO ... exists`。影响：改名工程首编译必失败 | EV-1 | 已由源码+实验三角定位：① unified flow 中 netlist 派生 ISF 恒先重放且含 create_*（efx_run_pt_unified.py L244-248）；② 持久化 peri.xml 的 GPIO netlist 锁绑定旧工程名 `.peri.db`，改名后锁源不匹配触发重复创建（对比官方 helloworld 示例 peri.xml 无锁引用，可正常重放） | SDK 侧：jacket 以新工程名交付时，应交付"无 peri.xml + pins 风格 ISF（create 全注释）"让首次编译原生重建，或在交付时用目标工程名重新生成 peri.xml；文档侧：rules §15 可补充"改名 = 新基线，peri.xml 必须原生重建，不可携旧锁拷贝" | SDK |
| C-2 | 期望：SDK 提供 import_gpio.bat 干跑校验。现象：本环境（catalog 0.9.6 安装）未随附该启动器 | — | 未确认（仅观察到路径不存在） | 在 SDK cli 交付面恢复/注明该启动器位置；本次以原生编译 PT 重放替代校验 | SDK |
| C-3 | 期望：宿主终端可用官方 setup.bat。现象：安全策略禁 cmd /c，且跨命令环境变量不持久 | — | 已确认（工具错误信息 + 二次运行 PYTHONHOME 丢失） | 已用 PowerShell 等价环境翻译绕过（记录于 review，属环境适配非工具 workaround） | 本项目 |

## Project lessons and SDK feedback

Project-specific lessons:
- unified flow 下用户 ISF 永远保持 pins 风格（create_* 注释）；RTL 端口 GPIO 由 map netlist 自动创建并加锁。
- 工程改名后旧 peri.xml 不可复用：其 netlist 锁指向旧名 `.peri.db`。标准动作 = 删 peri.xml → 首编译原生重建 → 重放编译验证（本次双 PASS）。
- efx_run stdout 无时间戳且确定性输出：不同次 PASS 日志字节一致，留证时需辅以产物 mtime。

Candidates transferable to the SDK: C-1（jacket 改名交付策略）、C-2（import_gpio 启动器交付面）。

Development intake location and status: not consolidated（本 review 即现场记录，未进入 SDK 开发仓）。

## Material gaps and later follow-ups

- 修正尝试 A（启用 create_* + 无 peri.xml）的失败日志未单独留存（现象与 run1 相同，已由源码逻辑与后续实验佐证）。
- sim/tb_led_marquee.v 未运行；marquee-lab 名下无仿真 PASS 记录。
- 烧录与板级观察未执行。
- 后续若跑仿真/上板，追加日期与结果到本节。

### 2026-10-17 追记：改名自动适配机制调查（用户提问触发）

两个补充实验（均在 %TEMP%，日志已快照）：

| 实验 | 输入 | 结果 |
|---|---|---|
| rename-probe（EV-7） | 拷贝 marquee-lab → 改名 rename-probe，peri.xml 剥离全部 netlist 锁（12×netlist_config + 1×partial_design），内部 name 留旧值 | interface FAIL，仍 `GPIO clk_50m_i exists` ×3 —— 证伪"去锁即便携"假设：已持久化的普通 GPIO 无论有无锁，都与 netlist ISF 的自动创建冲突 |
| hw-control（EV-8） | 官方 helloworld-unified 原样编译（Ti60F225，2026.1） | 四阶段全 PASS —— 控制组 |

对照官方 peri.xml 结构得到修正结论（取代 C-1 中"锁源不匹配"的单一归因）：

- 官方快照的 `gpio_info` 只含 `pll_refclk`（硬 IP comp_gpio，`conn_type="pll_clkin"`）+ PLL 硬 IP 块 + bank 电压 + ctrl/seu/clkmux；**不含任何普通 RTL 端口 GPIO**（led/rstn/reverse 全部每次编译由 map netlist 重建）。
- RTL 侧用 `(* syn_peri_port = 0 *)` 显式把 PLL 时钟口排除出自动推断。
- 即：**peri.xml 的"便携形态"= 只持久化 RTL 推不出的状态（bank/硬 IP/comp_gpio）；普通 GPIO 是易失态，不该进发货快照**。run3 之所以能重放 PASS，是因为锁与当前工程名一致（稳态）；probe 证明同批 GPIO 无锁时同样冲突——持久化普通 GPIO 只在"锁与当前名精确一致"时安全，跨名必炸。
- C-1 修正建议：catalog jacket 打包时从验证编译产出的 peri.xml 中**剔除普通 GPIO 条目**（保留 bank/硬 IP/comp_gpio/全局 unused 配置）；无硬 IP 的 jacket（如 marquee）该形态退化为"可不发 peri.xml"，拷工程=XML+RTL+ISF+SDC，改名即用，首编译自动落带锁 peri.xml，零额外成本。

### 2026-10-17 追记 3：可靠流程闭环（@evoverse 正式版本）

用户以 @evoverse 发起 marquee v1 正式版本，控制面全程推进（revision 0→28）：

| 动作 | 结果 |
|---|---|
| project.initialize → intent.create(marquee-v1, reliable) | rev 1→3 |
| simulation.profile.select（Phase A 风险事实 + Phase B 用户选择） | FPGA_FUNCTIONAL（服务端推荐=最低推荐，用户确认） |
| spec.draft（EXECUTABLE_2_0 密封包 design-packages/marquee-v1，digest 6792268e…）→ spec.approve（用户批准 SPEC-001） | rev 6→7 |
| candidate.deliver（7 文件） | 冻结 54757ad3…，但 tb 触发闭包扫描器 `integer count_ones(` 误判（已改 `[31:0]`） |
| verification.simulate ×2 | 两次 INCOMPLETE（规划错误，不落 evidence）：① tb 未接 EVOVERSE_PROPERTY 观测协议（DUT 本体自检 PASS：120 采样/29 旋转/0 错，run 6e8b6073）；② v2 补协议后缺 COV-001 事件——FPGA_FUNCTIONAL 下全场景为阻塞角色，绑定阻塞场景的覆盖义务进入阻塞集（run 390f69cf，301 事件全 pass，仅 COV-001 缺席） |
| 引擎缺口（C-4） | 规划层 INCOMPLETE 不记录 evidence → diagnostic.repair.record/candidate.repair 全部被 DIAGNOSTIC_REQUEST_REQUIRED/REPAIR_HYPOTHESIS_REQUIRED 阻塞 → **无候选重冻结出口**；两次修复均被迫走 intent.abandon(SUPERSEDED) → 重建意图链（v1→v2→v3，各含 profile×2 + spec 重登记 + 重批 + 重交付） |
| verification.simulate（marquee-v3, iverilog） | **PASS**：evidence `sim-b9448906e27d`（digest b9448906…，executionIdentityValid，moduleSimulation=PASS，scope CANDIDATE_SLICE） |
| candidate.promote | **基线安装**：baseline digest `550bb0d5…`，8 文件（含 SYSTEM.md）；asset module:marquee-core → BASELINE；intent marquee-v3 → PROMOTED（rev 28） |

git：`8b6f8c3`（可靠流程收尾，69 文件，含控制面状态/规格包/tb 修复）。

**证据边界**：仿真 PASS 为 FPGA_FUNCTIONAL 等级（moduleSimulation）；nativeBuild/programming/hardwareValidation 均为 NOT_RUN——此前 §1 的原生编译双连 PASS 属自由模式证据，未绑定本基线（可后续 build.native 补录）；板上观察为延期项。

**C-4（新增 SDK 反馈）**：harness 协议/事件覆盖缺口发生在 deliver 与 simulate 之间时，规划层 INCOMPLETE 不产生 diagnostic_requests，修复路径（diagnostic.repair.record → candidate.repair）无法进入，只能 supersede 重建整条意图链。建议：INCOMPLETE(TB_OBSERVATION_PROTOCOL_MISSING / 事件覆盖缺口) 时允许无证据绑定的候选重冻结（如 deliver 幂等重交或 repair 门放宽），避免两次 6 动作重建。

### 2026-10-17 追记 3.1：为什么这么简单的设计重建了两次（复盘，用户要求）

**结论先行**：DUT（RTL）零改动、与 catalog 硬件验证基线逐字节一致；两次重建全部消耗在 harness/适配层缺陷，且被引擎"冻结后无重冻结出口"放大成整条意图链重建。一次可归因于知识缺口（协议未前置暴露），一次可归因于本 Agent 流程失误（未审计期望义务集）。

**缺陷账本**（全部在 tb / spec↔tb 映射层，无一在 DUT）：

| # | 缺陷 | 暴露点 | 归因层 |
|---|---|---|---|
| 1 | `function integer count_ones(` 被闭包扫描器判为例化 | candidate.deliver | 引擎词法局限 + tb 风格；deliver 时可发现（确实当场发现并修复，未造成重建） |
| 2 | tb 未接 EVOVERSE_PROPERTY 观测协议 | simulate #1 | 知识缺口：协议只存在于引擎源码（observation.py），规格包/seal/技能文档均不投影 |
| 3 | COV-001 覆盖事件缺失 | simulate #2 | 本 Agent 流程失误：失败 #1 后只修了可见错误（协议），未读 run summary 的 `expected` 集审计全部义务——一次读取即可把 #2/#3 合并为一次修复 |

**放大机制（C-4 的因果链）**：deliver 冻结字节 → simulate 编译冻结副本 → 规划层 INCOMPLETE 不落 evidence → diagnostic_requests 为空 → diagnostic.repair.record（DIAGNOSTIC_REQUEST_REQUIRED）与 candidate.repair（REPAIR_HYPOTHESIS_REQUIRED）双门关闭 → 唯一出口 intent.abandon(SUPERSEDED) → 每次一行级 tb 修复成本 = 6 个控制面动作 + 1 次规格重批 + 1 次等级重选。两次共 12 动作。设计的不对称：DUT_FAIL 开诊断门（有证据），harness 协议失败被刻意当规划错误（防无证据重跑），副作用是修复通道也一并关闭。

**为什么没有前置拦截**：tb 需满足的完整契约（闭包词法约束、观测协议、阻塞义务集=绑阻塞场景的 property/oracle/coverage × requiredActivations）只有在 simulate 才第一次全量执行；期望义务集在任何交付前界面上都不可见——作者只能从失败反推。这是"隐性协议"问题，不是设计复杂度问题。

**改进项**：
- 引擎（并入 C-4）：① 首个 PASS 前的协议缺失/覆盖缺口允许幂等重交或放宽 repair 门；② 在 deliver 前投影 scoped Test IR 的期望义务集（ID + requiredActivations）；③ seal/lint 阶段检查 tb 闭包词法误判模式与协议行存在性。
- 文档：把 EVOVERSE_PROPERTY 线格式与"阻塞场景绑定覆盖义务亦阻塞"规则写进 evoverse-rtl 技能表面，而非仅存引擎源码。
- Agent（本例可避免的第二次重建）：任何 simulate 失败后，重建前必读 run 目录 summary.json 的 expected 集，一次性对齐全部义务再重交。


### 2026-10-17 追记 2：带硬核（PLL）场景的改名验证（用户提问触发）

| 实验 | 输入 | 结果 |
|---|---|---|
| hw-rename-probe（EV-9） | 官方 helloworld-unified（含 PLL 硬核 `pll_inst1` + comp_gpio `pll_refclk`）原样快照 → 改名 hw-rename-probe（peri.xml 仅重命名文件，内部 name 留旧值） | 四阶段全 PASS。落盘 peri.xml：design_db name 自动同步为新名；普通 GPIO（led/rstn/reverse）由 netlist ISF 原生重建并锁定 `hw-rename-probe.peri.db`；PLL 块完好 |

结论：**硬核场景下便携快照方案成立且 peri.xml 必发**——硬核块只存在于 peri.xml（RTL/netlist 均推不出），且硬核与 comp_gpio 不经 map netlist 重建、无 netlist 锁，天然改名安全；锁只打在普通 GPIO 上。RTL 侧硬核关联端口需 `(* syn_peri_port = 0 *)` 排除自动推断（官方同款）。`create_block`/`create_pll_input_clock_gpio` 仍仅用于无 peri.xml 的冷启动引导（§15 一次性仪式 + 双连 PASS），随快照交付时不需要。

<!-- evoverse-project-review:evidence
{"hardwareStatus":"NOT_RUN","evidence":[{"category":"build-fail","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/run1-fail-peri-replay.log","digest":"e4f4e39831c37df37e3619e34f08a8451cf03558e4c61658bb5f9688cac4f20c"},{"category":"build-pass","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/run2-bootstrap-pass.log","digest":"a7de7de34a50912c0e3bc25c79ec9bd39861d8f24731593663f778736cda0281"},{"category":"build-pass","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/run3-replay-pass.log","digest":"a7de7de34a50912c0e3bc25c79ec9bd39861d8f24731593663f778736cda0281"},{"category":"timing","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/run3-timing.rpt","digest":"0d7f9c539a0289293ad22573313b1f1a7c1d08ac4894bedc528b118b27cfeca4"},{"category":"build-fail","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/probe-striplocks-rename-fail.log","digest":"1ed5fc73b4e548d9f88a9c984cc6177e9b9559214c039140fbbcee197afaa70b"},{"category":"build-pass","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/control-helloworld-unified-pass.log","digest":"83f0ba2aa9533d7106f4aab31763d97f8adcf30e4253b50aae6ab7f39cb023b1"},{"category":"build-pass","path":"project-review/2026-10-17-marquee-lab-compile-baseline/evidence/probe-hardip-rename-pass.log","digest":"1ede6a4344df67da35ded3979c658f396510d11a44c13d14b29441a7d83dc283"},{"category":"simulation-pass","path":".evoverse/control/artifacts/runs/e44fefbb-22c9-4e77-92b4-12d676f6aa7a/summary.json","digest":"d1ebec3afc20b0941dd5dc6f2a6ffcefdc7f976af69b5071d5d97d75bb7d4830"}]}
-->
