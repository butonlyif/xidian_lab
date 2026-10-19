# marquee-lab 增量 segcount v1 -- 8 位数码管每秒 +1 计数显示

> 规格包：`segcount-v1@1`  
> 统一摘要：`781504fa9ee3dfb995e6e0bb3a1aca69c744d2a0505f80bb4efea1f9f0c858a6`

## 系统目标

在基线 marquee v1（跑马灯，基线摘要 550bb0d5）之上新增数码管计数功能：板上 8 位数码管（2x FJ3461AH，经 RN9/RN11）显示十进制计数，从 0 开始每秒加 1，前导零消隐（全零时仅最右位显示 0），0..99,999,999 回绕，BUT1 复位归零；驱动极性共阴假设（位选低有效、段高点亮，参数化，板上待确认）。基线跑马灯行为保持不变。单时钟域纯同步逻辑。

## 需求与验收

| 需求 | 说明 | 验收条件 |
|---|---|---|
| REQ-101 | 复位行为：arst_n_i 低有效异步复位；同步释放后计数值为 0（BCD 全零，显示层消隐为单个 0），节拍与扫描计数器清零。 | 同步释放后首个采样 bcd_r == 0；扫描/节拍计数器归零；输出无 X。 |
| REQ-102 | 计数主流程：每个 TICK_CYCLES（50 MHz / 50_000_000 = 1 Hz）计数值加一，BCD 进位链正确（9→10 等）；生产参数 8 位显示，仿真提速 TICK_CYCLES=4。 | 仿真中每次值变化严格等于期望值 +1（期望模型为十进制转 BCD）；连续 ≥12 次递增覆盖段图案 0-9 与进位。 |
| REQ-103 | 回绕边界：计数值到达位宽上限（10^DIGITS - 1）后下一次递增回绕到 0；用 DIGITS=2 旁证实例验证 99→00。 | 旁证实例观察到 ≥2 次 99→00 回绕且回绕后从 0 重新递增。 |
| REQ-104 | 显示扫描与集成：位选 one-hot（共阴低有效）按 SCAN_CYCLES（6250 → 1 kHz 刷新）轮转；段输出为当前位 BCD 的 0-9 译码（bit0..6=a..g，bit7=dp 熄灭）；前导零消隐；与基线跑马灯在同顶层共存（跑马灯 8 Hz one-hot 保持）。 | 仿真中每次扫描位切换时：dig == ~(one-hot<<idx)，seg == 消隐期望或译码期望；跑马灯四性质自检通过；联合仿真正常结束无 X。 |

## 系统组成与连接

### 系统框图

```mermaid
flowchart LR
    u_seg[数码管十进制计数显示核]
    u_marquee[[基线跑马灯核心（复用不改）]]
    classDef reuse fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#1e4620
    classDef adapt fill:#fef7e0,stroke:#f9ab00,stroke-width:2px,color:#7a5b00
    classDef new fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6
    classDef ctrl fill:#f3e8fd,stroke:#a142f4,stroke-width:2px,stroke-dasharray:4 2,color:#5b1a7a
    class u_seg new
    class u_marquee reuse
```

### 实例与连接

| 实例 | 层级 | 物料状态 | 契约 |
|---|---|---|---|
| u_seg | module | NEW | segcount-display |
| u_marquee | module | REUSE_UNCHANGED | marquee-baseline-led |

| 连接 | 源 | 目标 | 协议 | 类型 | 拓扑 | CDC 策略 |
|---|---|---|---|---|---|---|

## 时钟与复位语义

**时钟域**

| 时钟域 | 频率 Hz |
|---|---|
| clk_50m | 50000000 |

**复位域**

| 复位域 | 时钟域 | 极性 | 断言方式 | 释放方式 |
|---|---|---|---|---|
| rst_board_n | clk_50m | active-low | 异步断言（板上按键 BUT1，arst_n_i@A4） | 同步释放：各核内 3 级同步器，域内独立 |


## 物料来源与复用依据

### 基线 marquee v1 跑马灯核心（已晋级基线复用）

对外可观察行为：50 MHz 时钟 + 低有效异步复位输入，LEDS 位 one-hot LED 输出每 STEP_CYCLES 周期左移一位并回绕，复位释放后从 LED0 开始。

- 分类：`REUSE_UNCHANGED`
- 来源：baseline://marquee-lab/550bb0d577c4698a299c3e5021939e4a8b11127d1318237e9e54ab22b0aabb01（rtl/led_marquee.sv）（marquee v1 baseline（intent marquee-v3 PROMOTED），许可：项目自有（源自 EvoVerse catalog marquee jacket，已随基线晋级））
- 源摘要：`adb17f9fcf112530a8630c254eff7da393bbeb221f82058f1c550ca6c70b42a7`
- 使用原因：基线在 marquee-v3 意图下通过 FPGA_FUNCTIONAL 阻塞仿真（sim-b9448906e27d PASS）并晋级；本增量顶层仅扩展端口与例化，核心行为零变更。
- 证据适用范围：; ; 
- 适用配置：device=Trion T20F256（timing model C4）；board=t20f256-xd-ps-eval；clockHz=50000000；ledCount=10
- 失效条件：基线跑马灯需求变更（步进频率/LED 数/复位语义）; 顶层时钟或复位架构变更; 基线 digest 550bb0d5 被替代且行为变化
- 集成检查：扩展后顶层联合仿真中跑马灯四性质自检持续通过（tb 基线保持检查）; pins ISF 中 LED 管脚条目保持基线值不动; SDC 不变（同 clk_50m 单时钟域）

| 端口 | 方向 | 位宽 | 时钟域 | 复位域 |
|---|---|---|---|---|
| clk_i | input | 1 | — | — |
| rst_n_i | input | 1 | — | — |
| led_o | output | 10 | — | — |

## 模块设计

### 参数化数码管十进制计数显示核

单时钟域 BCD 十进制计数（每 TICK_CYCLES 加一，10^DIGITS 回绕）+ 数码管动态扫描显示（one-hot 位选、0-9 段译码、前导零消隐）；驱动极性参数化（默认共阴：位选低有效、段高点亮）；复位异步断言、3 级同步器同步释放。

**职责**

- 产生周期 TICK_CYCLES 的 1 Hz 计数节拍（clock enable，不派生时钟）
- 维护 DIGITS 位 BCD 计数：进位链递增，全 9 回绕归零
- 产生周期 SCAN_CYCLES 的扫描节拍与 0..DIGITS-1 循环位索引
- 输出当前扫描位的段译码（含消隐）与 one-hot 位选，按极性参数映射后寄存输出

**非职责**

- 数码管管脚与 IO 电平分配（板级约束，由 pins ISF 承担）
- 驱动极性的物理确认（共阴/共阳为参数化假设，板上验证）
- 位序物理布局确认（假设 sel1=最低位/最右，板上验证）
- 跑马灯功能（基线模块 u_marquee 承担，本模块不触碰）

**参数与约束**

| 参数 | 类型 | 默认值 | 约束 | 行为影响 |
|---|---|---|---|---|
| DIGITS | integer | 8 | 板上固定 8（2x FJ3461AH）; 仿真旁证实例取 2 以验证回绕 | BCD 位宽与回绕上限 10^DIGITS-1；位选总线宽度 |
| TICK_CYCLES | integer | 50000000 | TICK_CYCLES = f_clk / f_count；50 MHz / 1 Hz; 仿真提速取 4 | 计数频率：每 TICK_CYCLES 个时钟周期计数值加一 |
| SCAN_CYCLES | integer | 6250 | SCAN_CYCLES = f_clk / (刷新率 x DIGITS)；6250 → 1 kHz 刷新; 仿真提速取 2 | 每位点亮时长与整屏刷新率 |
| SEG_ACTIVE_HIGH | bit | 1 | 共阴假设=1（板上待确认）; 共阳=0 | 段输出极性映射（译码结果或其反相） |
| DIG_ACTIVE_LOW | bit | 1 | 共阴假设=1（板上待确认）; 共阳=0 | 位选输出极性映射（one-hot 或其反相） |

| 端口 | 方向 | 类型 | 位宽 | 时钟域 | 复位域 | 协议角色 | 空闲值 |
|---|---|---|---|---|---|---|---|
| clk_i | input | logic | 1 | clk_50m | rst_board_n | clock | — |
| rst_n_i | input | logic | 1 | clk_50m | rst_board_n | reset | — |
| seg_o | output | logic | 8 | clk_50m | rst_board_n | data | 8'b0（复位后全灭） |
| dig_o | output | logic | DIGITS | clk_50m | rst_board_n | data | 全 1（共阴：全不选通） |

**内部数据对象**

| 名称 | 作用 | 位宽 | 复位值 | 更新条件 | 所有权 |
|---|---|---|---|---|---|
| tick_cnt_r | 1 Hz 计数节拍计数器（clock enable） | 26 | 0 | 每个 clk_i +1；计满 TICK_CYCLES-1 产生单周期 tick_1hz 并清零（$clog2(50_000_000)=26） | owned |
| scan_cnt_r | 扫描节拍计数器 | 13 | 0 | 每个 clk_i +1；计满 SCAN_CYCLES-1 产生 scan_tick 并清零（$clog2(6250)=13） | owned |
| scan_idx_r | 当前扫描位索引（0..DIGITS-1 循环） | 3 | 0 | scan_tick 时 +1，到 DIGITS-1 回 0 | owned |
| bcd_r | DIGITS 位 BCD 计数值（idx0=最低位） | 32 | 0 | tick_1hz 时进位链 +1；全 9 回绕归零 | owned |
| seg_r | 段输出寄存器（极性映射后） | 8 | 0 | 每 clk 按当前位译码/消隐 + SEG_ACTIVE_HIGH 映射更新 | owned |
| dig_r | 位选输出寄存器（one-hot + 极性映射） | DIGITS | 全 1（不选通） | 每 clk 按 scan_idx_r one-hot + DIG_ACTIVE_LOW 映射更新 | owned |

**运行行为**

- 延迟：1 cycle
- 启动间隔：50000000 cycle
- 反压：无：自由运行的显示驱动输出，无握手
- 错误处理：无错误态：BCD 结构性合法，同步复位保证确定性初值

## 算法原理

## 验证策略

### Scenarios

- `SCEN-101`（segcount-display）：前置：arst_n_i 已断言至少 3 个时钟周期; clk_i 稳定运行；激励：释放 arst_n_i；结束：观察到第一次计数递增前的首采样完成
- `SCEN-102`（segcount-display）：前置：复位已释放; TICK_CYCLES 提速为 4（生产 50_000_000）；激励：自由运行 clk_i；结束：递增次数 ≥12
- `SCEN-103`（segcount-display）：前置：复位已释放; 旁证实例 DIGITS=2、TICK_CYCLES=4；激励：自由运行 clk_i 直至计满；结束：回绕事件 ≥2 次
- `SCEN-104`（segcount-display）：前置：顶层 top + led_marquee + seg7_counter 联合编译通过；激励：施加 50 MHz 时钟与一次上电复位序列；结束：扫描校验 ≥16 次、跑马灯 ≥10 转、递增 ≥12 次后正常结束

### Oracles

- `ORC-101`（segcount-display）：—；比较：精确相等：同步释放后第一个采样点比较 BCD 与节拍状态；时序窗：rst_sync_r[2] 上升后 1 个采样内；失败判定：释放后首采样 bcd_r != 0，或复位期间输出出现 X
- `ORC-102`（segcount-display）：—；比较：与十进制→BCD 期望模型逐事件精确比对（含 9→10 进位）；时序窗：≥12 次递增；失败判定：任一次变化与期望模型不符
- `ORC-103`（segcount-display）：—；比较：回绕事件序列精确匹配（99 → 00 → 01 …）；时序窗：≥2 次回绕；失败判定：99 之后变化值非 00，或回绕后递增异常
- `ORC-104`（segcount-display）：—；比较：每次扫描位切换逐项比对位选/段译码/消隐期望；跑马灯四性质计数校验；自检标记存在且 PASS；时序窗：整个联合仿真运行；失败判定：任一扫描输出与期望不符、跑马灯性质破坏、仿真挂起/超时/出现 X、自检 FAIL

### Properties

- `PROP-101`（segcount-display）：当 rst_sync_r[2] 上升（复位同步释放完成） 时，应满足 bcd_r == 0; tick_cnt_r == 0; scan_cnt_r == 0；至少激活 1 次；观测信号：rst_sync_r, bcd_r, tick_cnt_r, scan_cnt_r
- `PROP-102`（segcount-display）：当 bcd_r 在第 n 次变化后等于 to_bcd8(n) 时，应满足 下一次变化后 bcd_r == to_bcd8(n+1); 两次变化之间 bcd_r 保持不变；至少激活 10 次；观测信号：bcd_r
- `PROP-103`（segcount-display）：当 计数值到达 10^DIGITS-1（旁证实例 99） 时，应满足 下一次递增结果为全零; 回绕后递增序列从 1 继续；至少激活 2 次；观测信号：bcd_r, u_wrap.bcd_r
- `PROP-104`（segcount-display）：当 scan_idx_r 切换到 idx 时，应满足 dig_o == ~(one-hot<<idx)（共阴）; seg_o == (idx > msb ? 0 : decode(bcd[idx])); dp 段恒灭；至少激活 8 次；观测信号：dig_o, seg_o, scan_idx_r, bcd_r

### Coverage

- `COV-101`（segcount-display）：FPGA_FUNCTIONAL 下覆盖率为延期证据（非阻塞）；递增与扫描事件按次发射，冒烟窗口顺带满足全部 bin

## 需求追踪

| 需求 | 模块 | 算法 | 场景 | Oracle | Property | 覆盖 |
|---|---|---|---|---|---|---|
| REQ-101 | segcount-display |  | SCEN-101 | ORC-101 | PROP-101 |  |
| REQ-102 | segcount-display |  | SCEN-102 | ORC-102 | PROP-102 | COV-101 |
| REQ-103 | segcount-display |  | SCEN-103 | ORC-103 | PROP-103 |  |
| REQ-104 | segcount-display |  | SCEN-104 | ORC-104 | PROP-104 | COV-101 |
