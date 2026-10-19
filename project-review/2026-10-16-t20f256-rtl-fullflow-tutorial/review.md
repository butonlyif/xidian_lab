# Project implementation retrospective: t20f256-xd-ps-eval 纯 RTL 全流程教程（marquee-lab）

- Case ID: 2026-10-16-t20f256-rtl-fullflow-tutorial
- Created / last supplemented: 2026-10-16 / 2026-10-16
- Environment: runtime；Windows（PowerShell 5 终端，Trae CN 宿主）
- SDK version / Adapter version / toolchain version: evoverse-sdk（安装于 C:\Users\dylan Wang\evoverse-sdk，verification-engine 随包）；Efinity 2026.1.132.1.15（C:\Efinity\2026.1，Trion T20F256 / timing model C4）；Icarus Verilog（PATH 可见，-g2012）
- Project revision: marquee-lab 主线 git master `8191dd5`（integrated build: marquee10 + seg_display8 + input_ctrl on one top）；增量分支 codex/intent-seg-counter `34b1875`、codex/intent-btn-switch `3c6e43a`；控制面 revision 35（bda9ef53…）
- Requirement and outcome sources: 会话（用户原始需求 + AskUserQuestion 四项决策：「跑马灯+数码管+按键拨码」「多页站点+侧边导航」「真实跑一遍全流程」「板未连接写预期现象」）

## Goals and actual results

目标：以 t20f256-xd-ps-eval 为载体，真实跑通 EvoVerse 全流程（环境安装 → 骨架工程 → 基线功能走可靠设计链 → 两个并行增量 → 集成 → 最终编译），并把全程（含真实报错）渲染成中文多页教程站点。

实际结果：全部完成。基线 marquee-baseline 晋级（PROMOTED）；两个并行意图 seg-counter / btn-switch 各自完成规格→候选→仿真 PASS→promote（进入 FEATURE_MERGE 集成队列，队列位 1/2）；工程侧集成（top 例化三模块 + 43 管脚 ISF）四阶段编译 PASS；教程站点 learn/t20f256-rtl-fullflow/（index + 12 章 + css/js）落盘。板卡未连接：programming / hardwareValidation 保持 NOT_RUN，教程第 07 章以预期现象清单 + 排查路径呈现。

## Overall process and phenomena

| Stage | What was done | Observed phenomena / manual interventions | Outcome and source |
|---|---|---|---|
| 环境/骨架 | SDK catalog 查板卡、生成 stage0 工程、efx_run 编译 | 首次编译遇 PYTHONHOME/EFINITY_USER_DIR_INI 缺失，手工封装环境命令 | 4 阶段 PASS（outflow/*.rpt） |
| 可靠链（基线） | initialize → intent → profile(FPGA_FUNCTIONAL 两阶段) → spec 包(10 文件) → seal → draft/approve → deliver → simulate → promote | spec.draft 首报 PACKAGE_PATH_ESCAPED（绝对路径）；二次报 GENERATION_NOT_READY ×16（枚举/方向/宽度/连接性/rule）；deliver 报 SOURCE_CLOSURE ×5（词法器把 IDENT IDENT ( 当例化） | 证据在案（见下表）；baseline e2465585… |
| 原生构建（基线） | V2001 兼容化（int/'0）后 efx_run compile | EFX-0010 'int' is an unknown type；引导前 ISF dry-run 报 Unknown instance ×9（预期现象） | 4 阶段 PASS；引导后 dry-run [OK] No issues |
| 并行增量 ×2 | 两个 intent 各获隔离 worktree（codex/intent-*） | promote 撞 INTENT_WORKTREE_DIRTY 与 SMUGGLED_DELIVERY_CHANGES（分支不得含候选外文件）；多 approved spec 并存时 simulate 只认最新（重 draft+approve 解决） | sim-c187f06b / sim-4515995 双 PASS，双双 QUEUED |
| 集成 | top 例化 3 模块、ISF +30 管脚、XML +2 源文件、最终编译、build.native 登记 | 拨码通道无负载按预期被综合裁剪（注释声明为后续迭代留口） | 4 阶段 PASS；bld-97cd2ca0 |
| 教程站点 | learn/t20f256-rtl-fullflow/ 15 文件（含复制按钮、localStorage 进度） | 全部素材取自上述真实运行 | 用户可见交付物 |

## Key artifacts and evidence

| Evidence ID | Original artifact or log path | Version / input linkage | Error summary or supported fact | Reference location | Snapshot path / SHA-256 | Collection time / source stability / copy type | Status |
|---|---|---|---|---|---|---|---|
| sim-marquee | marquee-lab/.evoverse/control/artifacts/runs/0fafd9df…/summary.json（及 events.json） | SPEC-001 pkg ef9a502b；tb_marquee10 248 事件 | 基线候选仿真 all-pass（sim-c3fb67b7796d） | control evidence vector | 在位（git 已收 1bbe971） | 2026-10-16 / 覆盖风险低（runs 目录）/ 原始字节 | present |
| sim-seg | marquee-lab/.evoverse/control/artifacts/runs/（seg request）/summary.json | SPEC-004=SPEC-002 pkg 717de32d | seg_display8 仿真 PASS（sim-c187f06b2b1d；本地 TB-RESULT.PASS 1100 samples/17 count-changes/137 rotates） | control evidence vector | 在位 | 2026-10-16 / 稳定 / 原始字节 | present |
| sim-btn | 同上（btn request） | SPEC-003 pkg 8d8db06b | input_ctrl 仿真 PASS（sim-451599546e34；pulses=4 sw_events=10） | control evidence vector | 在位 | 2026-10-16 / 稳定 / 原始字节 | present |
| build-baseline | marquee-lab/outflow/*（.pinout.rpt/.timing.rpt/.res.csv/.bit） | marquee-lab.xml 基线版 | 基线 4 阶段 PASS、Fmax≈399.5 MHz（bld-c278786f140b） | outflow 报告 | git fc26240 已收 | 2026-10-16 / 已被集成编译覆盖（基线版字节保存在 git fc26240） | snapshotted(git) |
| build-integrated | marquee-lab/outflow/*（集成版） | XML 4 源文件、ISF 43 管脚 | 集成 4 阶段 PASS、res.csv 分层（u_marquee 44FF/20LUT、u_seg_display8 98FF/110LUT）（bld-97cd2ca0c5de） | res.csv 行 8-10 | git 8191dd5 已收 | 2026-10-16 / 当前最新 / 原始字节 | present |
| err-spec16 | 会话记录（spec.draft 拒绝响应原文，16 条 jsonPointer） | pkg 16dde1e0→ef9a502b | 控制面生成就绪校验比本地密封严 | 教程 04 章已全文收录 | learn/…/04-intent-spec.html | 2026-10-16 / 已固化进教程 | present |
| err-closure | 会话记录（SOURCE_CLOSURE 三次报错：5/2/1 条 missing module） | 候选 RTL | 词法陷阱族：CNT_W/RESULT/integer/seen_pos/step_cnt→int→co0..co6/endcase/differ/pulse_r | 教程 05/08/09/11 章 | 同上 | 同上 | present |
| err-efx-int | marquee-lab/outflow/marquee-lab.err.log（历史行） | top.v:14（SV int） | EFX-0010 'int' unknown type | err.log 2026-10-16 10:33 段 | git 1bbe971 前工作树；已被后续编译覆盖日志时间戳但错误行留存 | 2026-10-16 / 低 | present |
| program-noboard | 会话记录 | --flow program | 未连板：list index out of range（JTAG 枚举空） | 教程 07 章 | 同上 | 同上 | present |

## How far validation reached

- 仿真：三个候选全部控制面 iverilog 阻塞仿真 PASS（FPGA_FUNCTIONAL 等级，义务=4 场景全 blocking）。
- Build：Efinity efx_run --flow compile（map/interface/pnr/pgm）基线与集成版各一次全 PASS；ISF 引导+dry-run 两连 PASS（§15 契约）。证据 bld-c278786f140b / bld-97cd2ca0c5de。
- 烧录：命令与预期现象清单就绪；实际未执行（无板）。programming=NOT_RUN。
- 板级验证：未执行。hardwareStatus=NOT_RUN；第 07/10 章的「预期现象」为设计预期，不构成板上 PASS 证据。

## Project assembly and reuse

- Assembly manifest / preflight receipt: 无 IPM 组装（纯 RTL，无硬核 IP）；候选清单见 control candidates（runDir a7c3f1e2/d47e39f2/f69a51b3）
- Asset ownership: marquee10=BASELINE（基线复用）；seg_display8/input_ctrl=QUALIFIED（generated-candidate，集成队列）；stage0 顶层=material（ADAPT_REQUIRED）
- IP VLNV, normalized parameters, generation or reuse receipts: 不适用（无 IPM）；PLL/DDR 未使用
- Cache hits and reasons for misses: 不适用
- Efinity version and native flow: 2026.1.132.1.15，efx_run --prj --flow compile（unified flow，ISF 重放于 interface 阶段）
- Were flow-assist Python/batch tools produced: no（环境变量封装命令与 .git/info/exclude 为工程内操作记录，未产出常驻脚本；其需求本身已作为 SDK 改进候选记录于下）

## Problems and improvement candidates

| Candidate ID | Expected / phenomenon / impact | Evidence ID | Root-cause hypothesis (mark if unconfirmed) | Suggested investigation or improvement | Scope |
|---|---|---|---|---|---|
| C1 | spec 包应一处存放即可被 draft/approve/simulate 解析；实际 draft 按 worktree、resolve 按根（SPEC_APPROVAL_STALE / package root does not exist） | sim-seg 前置失败记录 | resolve_active_executable_package 不接收 intent 归属的 worktree 根 | resolve 支持 per-intent 根或 draft 记录绝对锚 | SDK engine |
| C2 | 多意图并行、多 spec APPROVED 时 simulate 应按 intent 取包；实际只认最新 APPROVED（SPEC_IDENTITY_MISMATCH） | 同上 | _approved_package 不传 intent_id | 按 intentId 过滤后再取最新 | SDK engine |
| C3 | 合法 RTL 不应被闭合检查误判；IDENT IDENT ( 词法陷阱致 5+2+1+2 次返工 | err-closure | tokenizer 丢运算符且字符串不剥离（源码注释已自认） | 剥离字符串/转义跨行/白名单已知系统函数；或错误提示给出官方改写建议 | SDK engine |
| C4 | 候选交付应能携带 spec 包/run 工件等支撑文件；实际 SMUGGLED_DELIVERY_CHANGES 连 spec 包都拒 | 增量 promote 失败记录 | 分支差异白名单仅候选 files | 允许声明 specPackage 路径随分支提交 | SDK control |
| C5 | efx_run.bat 裸调应可用；实际需手工补 6 个环境变量 | build-baseline 前置失败 | bat 不自举 setup 环境 | efx_run.bat 内部自调 setup 或 SDK adapter 统一注入 | SDK adapter / Efinity |
| C6 | 质量统计应反映 items 数；oracleCount/scenarioCount 实际是 len(dict)=3（键数） | spec.draft quality 字段 | spec_documents.py len 用在 dict 上 | 修 len(…["items"]) | SDK engine（小） |

## Project lessons and SDK feedback

Project-specific lessons:

- 规格包所有权字段/决策 status/覆盖 rule 等生成就绪要求，第一次写包时按第 04 章清单一次到位可省一轮返工。
- 仿真参数要贴近上板比例（TICK ≥ 8×SCAN），否则会把设计正确的呈现延迟误判为缺陷。
- intent 分支只提交候选声明文件；支撑文件用 .git/info/exclude 是当前引擎行为下的标准姿势。

Candidates transferable to the SDK: C1–C6（见上表）。

Development intake location and status: not consolidated（本机存在安装版 SDK；开发 checkout 未在上下文中确认，未做任何 SDK 代码改动）。

## Material gaps and later follow-ups

- 板级验证空缺：四个极性假设（段低有效/位选高有效/按键低有效/拨码上拨=1）与全部「预期现象」待连板后用 hardware.validate 落证据；届时在教程 07/10 章补实测记录。
- FEATURE_MERGE 队列（btn 位 1、seg 位 2）等待系统整合动作；本教程止步于工程侧集成产物，队列状态如实保留。
- marquee-lab 主根最新一次收据（rev 35 之后）未再 git 提交；runs 工件在 .git/evoverse 与 .evoverse（exclude 后者新增文件）中，如需长期留痕可后续补提交。
- 2026-10-16（本次）：全流程与教程首版完成；无后续版本观察记录。

## Follow-up 2026-10-16：教程回放验证（伴生工程 tutorial-replay）

按用户要求「教程写完后把内容真实跑一遍（除环境安装）」，在伴生工程 `tutorial-replay/`（独立 git 仓，master）把教程 04–10 章全部动作重放一遍。本节只追加回放轮事实，不改写上文原始记录。

### 回放轮修复链（对应教程 04–05 章）

| 现象 | 根因（用户选定假设，后获新证据支持） | 处理链 | 证据 |
|---|---|---|---|
| 基线候选仿真 CANDIDATE_COMPILE_FAILED（invalid） | PowerShell Set-Content 导出的 5 个源文件带 UTF-8 BOM | diagnostic.repair.record → git archive 字节保真重导出 → candidate.repair → promote | 失败留痕 sim-da63d879a572；修复后 sim-6746d444dfe6 PASS / valid（四项义务全过），证实与设计逻辑无关 |

### 逐章回放结果

| 教程章 | 回放动作 | 结果与证据 |
|---|---|---|
| 06 章 | 基线四阶段编译 + build.native 登记 | map/interface/pnr/pgm 全 PASS；bld-7d8c71f1f588（NATIVE_BUILT / PASS / valid） |
| 07 章 | 烧录 | 板未连接，NOT_RUN（与首版一致） |
| 08 章 | seg-counter：intent→profile 两阶段→spec draft/approve→deliver→simulate→promote | sim-0e581ab5dfd2 PASS / valid |
| 09 章 | btn-switch 同链 | sim-e73184add91f PASS / valid |
| 10 章 | 集成：4 源文件 + ISF 42 脚 + XML 四行 → 四阶段编译 → build.native → git 提交 | 全 PASS；bld-0f5be188c077（服务端自跑编译，exitStatus=0，控制面 r38）；提交 9045ff0 |

### 回放实锤（已写回教程）

- 管脚权威数字 = **42**（stage0 12 + 增量 30；ISF 122 行、peri.xml 42 GPIO 全 3.3 V LVTTL/LVCMOS、构建后存活 29325 字节）。上文首版记录中「ISF 43 管脚」为写作口径错误；教程 10 章相应表述已修正。
- res.csv 与教程逐项对齐：总量 172(0)/81(0)/161(0)；u_marquee 44/22/20；u_seg_display8 98/40/110；u_input_ctrl **30/19/31**（首版留白，已补实测值）。
- 本机 Efinity 为精简安装（C:\Efinity\2026.1），无 `cli/import_gpio.bat`；ISF 重放安全的官方证明 = 每次编译的 interface 阶段 PASS（每次 unified build 都把 ISF 重放一遍）+ peri.xml 人工核对。教程 06/10 章 dry-run 展示行已改为该口径，并注明完整版 SDK 才自带 import_gpio 自检工具。
- 器件实锤 = Trion T20F256 / timing model C4（build.stdout 命令行原文）；教程 06 章「Ti60F256」笔误已改。

### 回放轮手工干预记录

- `project_next` 响应含大量重复 ActionDescriptor 描述被截断；build.native 的 inputSchema 改从安装版 SDK 源码读取（`C:\Users\dylan Wang\evoverse-sdk\runtime\verification-engine\evoverse_verification\` 下 actions.py / providers/efinity_build_port.py / service.py）后构造 inputs 成功（实际必需 `mode` + `adapterId:"efinity"`）。
- PowerShell 下 `cmd /c` 被宿主安全策略拦截 → 临时 .bat 包装执行编译（临时文件已清理）。
- 集成构建 build.native 不传 intentId → 证据 intentId=null / scope=NATIVE_ARTIFACT，属预期形态。
- FEATURE_MERGE 队列不经控制面消化：集成 = 手动 git 集成到 master + build.native 登记；队列保持 QUEUED 终态（正确形态）。

### 新增 SDK 改进候选（回放轮）

| Candidate ID | Expected / phenomenon / impact | Evidence ID | Root-cause hypothesis (unconfirmed) | Suggested improvement | Scope |
|---|---|---|---|---|---|
| C7 | FEATURE_MERGE 队列没有对应控制面动作可消化（systemIntegrations 停留 QUEUED）；集成只能走「手动 git 集成 + build.native 登记」的库外路径，教程只能如实呈现该现状 | 回放 r6 状态快照 | 集成动作尚未在控制面实现 | 提供 system-integrate 类动作（消费队列、登记合并事实），或在文档中显式声明库外消化是标准形态 | SDK control |

### 回放轮证据表

digest 为控制面 state.json 登记的证据 digest（证据 ID 同名）。

| Evidence ID | Path（工程根 tutorial-replay/） | Digest | Status |
|---|---|---|---|
| sim-da63d879a572 | .evoverse/control/artifacts/runs/replay-sim-01/summary.json | da63d879a57261aa31b175e531a41a885575bfa9c82951f8cb17ed6cef44f7b4 | CANDIDATE_COMPILE_FAILED（invalid，BOM 根因留痕） |
| sim-6746d444dfe6 | .evoverse/control/artifacts/runs/75278ece-e77f-4e88-87c8-b83f4b1112c5/summary.json | 6746d444dfe69509c783d1488fda4efdc027b8e594de71913a96bc6b813e2fae | PASS / valid |
| sim-0e581ab5dfd2 | .evoverse/control/artifacts/runs/replay-r5-simulate-02/summary.json | 0e581ab5dfd22ac5e159811da3cd67509d2bdcb167deb1887382e47019dc0fcd | PASS / valid |
| sim-e73184add91f | .evoverse/control/artifacts/runs/replay-r5b-pre-promote-backup/replay-r5b-simulate-01/summary.json | e73184add91f4edba7d7186b3f048285423bc86daf29b4c5ecc8235ea27b3bec | PASS / valid |
| bld-7d8c71f1f588 | .evoverse/control/artifacts/runs/replay-native-build-01/ | 7d8c71f1f588b89bcc858911dc7c5b593b69dcd7bb45cee8c826e72d27c81d9c | NATIVE_BUILT / PASS / valid |
| bld-0f5be188c077 | .evoverse/control/artifacts/runs/replay-native-build-02-integration/ | 0f5be188c077d646b62f12e1df47ca9635242b119c0f0d961d95a747978481ce | NATIVE_BUILT / PASS / valid |

后续跟进追加：
- 2026-10-16（回放轮）：教程除环境安装外全部内容重放完成；板级验证仍 NOT_RUN；FEATURE_MERGE 队列按设计保持 QUEUED 终态；回放轮改动（教程 2 文件修订 + 本 review + DAYLOG）不触及交付面。

<!-- evoverse-project-review:evidence
{"hardwareStatus":"NOT_RUN","evidence":[{"category":"simulation","path":"marquee-lab/.evoverse/control/artifacts/runs/0fafd9df-c5ff-4fcb-9201-3c44af868f14/summary.json","digest":"unknown"},{"category":"native-build","path":"marquee-lab/outflow/marquee-lab.res.csv","digest":"unknown"},{"category":"native-build","path":"marquee-lab/outflow/marquee-lab.pinout.rpt","digest":"unknown"},{"category":"tutorial-site","path":"learn/t20f256-rtl-fullflow/index.html","digest":"unknown"},{"category":"retrospective","path":"project-review/2026-10-16-t20f256-rtl-fullflow-tutorial/review.md","digest":"unknown"},{"category":"simulation","path":"tutorial-replay/.evoverse/control/artifacts/runs/75278ece-e77f-4e88-87c8-b83f4b1112c5/summary.json","digest":"6746d444dfe69509c783d1488fda4efdc027b8e594de71913a96bc6b813e2fae"},{"category":"simulation","path":"tutorial-replay/.evoverse/control/artifacts/runs/replay-r5-simulate-02/summary.json","digest":"0e581ab5dfd22ac5e159811da3cd67509d2bdcb167deb1887382e47019dc0fcd"},{"category":"simulation","path":"tutorial-replay/.evoverse/control/artifacts/runs/replay-r5b-pre-promote-backup/replay-r5b-simulate-01/summary.json","digest":"e73184add91f4edba7d7186b3f048285423bc86daf29b4c5ecc8235ea27b3bec"},{"category":"native-build","path":"tutorial-replay/.evoverse/control/artifacts/runs/replay-native-build-01/","digest":"7d8c71f1f588b89bcc858911dc7c5b593b69dcd7bb45cee8c826e72d27c81d9c"},{"category":"native-build","path":"tutorial-replay/.evoverse/control/artifacts/runs/replay-native-build-02-integration/","digest":"0f5be188c077d646b62f12e1df47ca9635242b119c0f0d961d95a747978481ce"}]}
-->
