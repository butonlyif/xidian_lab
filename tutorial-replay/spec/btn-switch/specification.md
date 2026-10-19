# 按键与拨码输入控制（btn-switch）

> 规格包：`marquee-lab-btn-switch@1.0.0`  
> 统一摘要：`c06d0eb7e6787595538c0a65abaa1f5d50faa64d6a1a61331277f917fa61e008`

## 系统目标

在 marquee-baseline 基线之上建立第二个并行增量：采集板上 BUT2/BUT3/BUT4 三个按键（低有效、上拉）与 SW1..SW10 十位拨码开关。按键经两级同步加 20 ms 稳定计数消抖后产生单周期脉冲，拨码经两级同步直采电平。全部逻辑运行在单一 50 MHz 时钟域，与基线共用时钟域与复位域。

## 需求与验收

| 需求 | 说明 | 验收条件 |
|---|---|---|
| REQ-1 | 任一按键输入稳定保持 DEBOUNCE_CYCLES（默认 1,000,000 个 50 MHz 周期，即 20 ms）为低后，在稳定达成的那一拍产生一个单周期 btn_pulse_o 高脉冲；每次按下沿恰好一个脉冲。 | 仿真中三次稳定按压（持续 > DEBOUNCE_CYCLES）各产生恰好 1 个单周期脉冲，脉冲总数与按压沿数相等。 |
| REQ-2 | 持续低电平时长小于 DEBOUNCE_CYCLES 的抖动毛刺不产生任何脉冲（含 DEBOUNCE_CYCLES-1 拍的最长拒判毛刺）。 | 注入短毛刺、中毛刺与 DEBOUNCE_CYCLES-1 边界毛刺各一类，脉冲计数保持不变。 |
| REQ-3 | 10 位拨码开关电平经 2 级同步器后在 2 个 clk_i 周期内反映到 sw_sync_o，纯电平跟随无消抖。 | sw_i 每次翻转后第 2 个上升沿起 sw_sync_o 与 sw_i 一致；10 位全部翻转覆盖。 |
| REQ-4 | 复位有效（rst_n_i 拉低）期间 btn_pulse_o=3'b000 且 sw_sync_o=10'b0。 | arst_n==0 的每个采样点两输出均为全零。 |

## 系统组成与连接

### 系统框图

```mermaid
flowchart LR
    u_input_ctrl[按键拨码输入控制 input_ctrl]
    u_stage0_top[(板级顶层（按键/拨码管脚扇出宿主）)]
    u_stage0_top -->|active-low-button-bus| u_input_ctrl
    u_stage0_top -->|positive-dip-bus| u_input_ctrl
    classDef reuse fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#1e4620
    classDef adapt fill:#fef7e0,stroke:#f9ab00,stroke-width:2px,color:#7a5b00
    classDef new fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6
    classDef ctrl fill:#f3e8fd,stroke:#a142f4,stroke-width:2px,stroke-dasharray:4 2,color:#5b1a7a
    class u_input_ctrl new
    class u_stage0_top adapt
```

### 实例与连接

| 实例 | 层级 | 物料状态 | 契约 |
|---|---|---|---|
| u_input_ctrl | module | NEW | input_ctrl |
| u_stage0_top | system | ADAPT_REQUIRED | mat-board-io |

| 连接 | 源 | 目标 | 协议 | 类型 | 拓扑 | CDC 策略 |
|---|---|---|---|---|---|---|
| c-btn-bus | u_stage0_top.btn_bus_o | u_input_ctrl.btn_i | active-low-button-bus | data | fan-out | single-domain |
| c-sw-bus | u_stage0_top.sw_bus_o | u_input_ctrl.sw_i | positive-dip-bus | data | fan-out | single-domain |

## 时钟与复位语义

**时钟域**

| 时钟域 | 频率 Hz |
|---|---|
| clk_50m | 50000000 |

**复位域**

| 复位域 | 时钟域 | 极性 | 断言方式 | 释放方式 |
|---|---|---|---|---|
| rst_sys | clk_50m | active-low | asynchronous | 3-stage synchronizer |


## 物料来源与复用依据

### 板级按键/拨码管脚扇出契约（BUT2/3/4 与 SW1..SW10）

把 3 路低有效按键与 10 路拨码管脚电平在顶层聚合为 btn_bus_o（3 位，低有效）与 sw_bus_o（10 位，上拨=1）扇出。

- 分类：`ADAPT_REQUIRED`
- 来源：catalog/boards/t20f256-xd-ps-eval/pinout/t20f256-xd-ps-eval.csv（USER_BTN_BUT2..4、DIP_SW1..10 行）（0.1.0，许可：EVOVERSE SDK 板卡目录，随工程分发）
- 源摘要：`0000000000000000000000000000000000000000000000000000000000000000`
- 使用原因：管脚与上拉信息来自 t20f256-xd-ps-eval 板卡 pin map（BUT2=B4、BUT3=A3、BUT4=A2、SW1..SW10=B15..B10，全部 3.3 V bank），是本工程对板载输入物料的唯一权威来源。
- 证据适用范围：板卡 pin map 解析（stage0 生成工程时同源）：BUT2/3/4=B4/A3/A2、SW1..10=B15..B10 实证
- 适用配置：device=Trion T20F256（t20f256-xd-ps-eval）；ioStandard=3.3 V LVTTL / LVCMOS；btnPolarity=active-low with pullup（BUT2=B4、BUT3=A3、BUT4=A2）；swPolarity=上拨=1（SW1..SW10 = B15,A15,B14,A14,B13,A13,B12,A11,B11,B10）
- 失效条件：更换板卡导致按键/拨码管脚映射变化; 按键改为高有效或拨码极性反转的板卡变体; 按键数量或拨码数量变化
- 集成检查：顶层把 user_btn2/user_btn3/user_btn4 依序汇入 3 位按键总线（bit0=BUT2）; 顶层把 dip_sw1..dip_sw10 依序汇入 10 位拨码总线（bit0=SW1）; ISF 中 13 个输入管脚均已 assign_pkg_pin 且 IO_STANDARD 为 3.3 V LVTTL / LVCMOS

| 端口 | 方向 | 位宽 | 时钟域 | 复位域 |
|---|---|---|---|---|
| btn_bus_o | output | 3 | clk_50m | rst_sys |
| sw_bus_o | output | 10 | clk_50m | rst_sys |

## 模块设计

### 按键消抖脉冲 + 拨码同步采样

把板级异步按键与拨码输入整理为时钟域内可信信号：按键经两级同步加稳定计数消抖，产生每按一次恰一个的单周期脉冲；拨码经两级同步直接输出电平。

**职责**

- 对 NUM_BTNS 路低有效按键做 2 级同步 + DEBOUNCE_CYCLES 稳定计数消抖
- 在每个按下沿（稳定判定达成且新稳定电平为按下）产生一个单周期脉冲
- 对 NUM_SW 路拨码做 2 级同步后输出电平
- 复位期间脉冲与拨码输出全零

**非职责**

- 不负责按键/拨码管脚电气属性（上拉、IO_STANDARD 由板卡与 ISF 管理）
- 不做拨码消抖（机械拨码切换速率远低于采样率，两级同步足够）
- 不解释脉冲语义（暂停/反向等由上层模块决定）

**参数与约束**

| 参数 | 类型 | 默认值 | 约束 | 行为影响 |
|---|---|---|---|---|
| NUM_BTNS | integer | 3 | 1 <= NUM_BTNS <= 8 | 按键路数（板载 BUT2/BUT3/BUT4 = 3 路） |
| NUM_SW | integer | 10 | 1 <= NUM_SW <= 32 | 拨码路数（板载 SW1..SW10 = 10 路） |
| DEBOUNCE_CYCLES | integer | 1000000 | DEBOUNCE_CYCLES >= 4; 50_000_000 * 0.02 = 1_000_000（20 ms @ 50 MHz） | 按键稳定判定阈值：低电平需连续保持该拍数才被接受；仿真用小值提速 |

| 端口 | 方向 | 类型 | 位宽 | 时钟域 | 复位域 | 协议角色 | 空闲值 |
|---|---|---|---|---|---|---|---|
| clk_i | input | clock | 1 | clk_50m | — | clock | — |
| rst_n_i | input | async-reset-active-low | 1 | clk_50m | rst_sys | reset | — |
| btn_i | input | logic | NUM_BTNS | clk_50m | rst_sys | data | — |
| sw_i | input | logic | NUM_SW | clk_50m | rst_sys | data | — |
| btn_pulse_o | output | logic | NUM_BTNS | clk_50m | rst_sys | valid | 无按键沿时全 0（常态 0，每个按下沿恰一拍 1） |
| sw_sync_o | output | logic | NUM_SW | clk_50m | rst_sys | data | 复位期间全 0；运行期间经 2 级同步跟随 sw_i |

**内部数据对象**

| 名称 | 作用 | 位宽 | 复位值 | 更新条件 | 所有权 |
|---|---|---|---|---|---|
| btn_sync_r | 按键两级同步链（2 级 × NUM_BTNS 位） | 6 | 全 1（同步链初值视为释放态） | 每个 clk_i 上升沿移位采样 btn_i | owned |
| btn_stable_r | 已接受的按键稳定电平（低有效） | 3 | 全 1（释放） | db_cnt 达 DEBOUNCE_CYCLES-1 且 btn_sync2 与其不同时锁存 btn_sync2 | owned |
| db_cnt | 按键稳定计数器（每键独立逻辑共用一组计数的向量化实现，规格按逐键语义） | clog2(DEBOUNCE_CYCLES) | 0 | btn_sync2 与 btn_stable 不同时每拍 +1（达阈值回零），相同时清零 | owned |
| pulse_r | 单周期脉冲寄存器 | 3 | 0 | 稳定达成拍且新稳定为按下（0）时置 1 一拍，其余拍清零 | owned |
| sw_sync_r | 拨码两级同步链（2 级 × NUM_SW 位） | 20 | 0 | 每个 clk_i 上升沿移位采样 sw_i | owned |

**运行行为**

- 延迟：0 cycle
- 启动间隔：1 cycle
- 反压：无——输入采样型模块，无 valid/ready 握手
- 错误处理：无错误通路；毛刺输入的拒判是设计行为而非错误

## 算法原理

### 两级同步 + 稳定计数消抖 + 按下沿单脉冲

把机械按键的异步抖动输入整理为时钟域内每按一次恰一个的单周期脉冲，同时以纯两级同步直采拨码电平。

按键先经 2 级同步链消除亚稳态；同步电平与已接受稳定电平比较，不同则稳定计数器累加，相同则清零；计数达到 DEBOUNCE_CYCLES-1 时接受新电平——若新电平为按下（0）且旧电平为释放（1），在该拍输出一个单周期脉冲。拨码每路只做 2 级同步。

**输入与输出**

| 方向 | 名称 | 类型 | 位宽 |
|---|---|---|---|
| 输入 | btn_i | active-low-button | NUM_BTNS |
| 输入 | sw_i | positive-level | NUM_SW |
| 输出 | btn_pulse_o | single-cycle-pulse | NUM_BTNS |
| 输出 | sw_sync_o | synced-level | NUM_SW |

**处理步骤**

1. 每个 clk_i 上升沿：btn_i 与 sw_i 各自经 2 级同步链移位采样（ASYNC_REG）
2. 按键：btn_sync2 != btn_stable 时 db_cnt 每拍 +1；相等时 db_cnt 清零
3. db_cnt == DEBOUNCE_CYCLES-1 的拍：btn_stable <= btn_sync2、db_cnt 清零；若新稳定为按下且旧稳定为释放，pulse 置 1
4. 拨码：sw_sync_o <= 同步链第 2 级，纯电平跟随

**公式**

- `btn_sync2 <= btn_sync1; btn_sync1 <= btn_i`
- `db_cnt_next = (btn_sync2 == btn_stable) ? 0 : (db_cnt == DEBOUNCE_CYCLES-1 ? 0 : db_cnt + 1)`
- `accept = (btn_sync2 != btn_stable) && (db_cnt == DEBOUNCE_CYCLES-1)`
- `btn_stable_next = accept ? btn_sync2 : btn_stable`
- `pulse_next = accept && (btn_stable == 全 1) && (btn_sync2 含 0 位)`
- `sw_sync_o <= sw_sync_r[1]`

- 数值策略：signed=—；binaryPoint=0；intermediateWidth=20；overflow=wrap；truncation=none
- 时序：延迟 0 cycle；启动间隔 1 cycle
- 边界：低电平保持恰 DEBOUNCE_CYCLES-1 拍后回高：不触发脉冲（拒判边界）; 低电平保持恰 DEBOUNCE_CYCLES 拍：触发脉冲（接受边界）; 同步链初值为释放态：复位释放后不产生虚假按下脉冲
- 非法输入：任何宽度小于 DEBOUNCE_CYCLES 的抖动都被拒判（计数中途回摆即清零），不存在误触发路径；DEBOUNCE_CYCLES>=4 由参数约束保证
- 参考模型：`accepted = 0 if glitch_low_cycles < DEBOUNCE_CYCLES else 1; pulse_count = number of accepted press edges; sw_sync = sw delayed by 2 cycles`
- 容差：精确——阈值判定，无数值容差

## 验证策略

### Scenarios

- `SCN-RESET`（input_ctrl）：前置：上电，时钟自由运行; rst_n_i 保持为 0，btn_i/sw_i 施加任意激励；激励：保持 rst_n_i=0 若干时钟周期，期间逐周期采样 btn_pulse_o 与 sw_sync_o; 释放 rst_n_i 后再运行若干周期，确认无虚假脉冲；结束：复位期间两输出全零成立；释放后同步链初值不产生任何脉冲
- `SCN-PRESS`（input_ctrl）：前置：复位已释放; 50 MHz 时钟自由运行（仿真用缩小的 DEBOUNCE_CYCLES）；激励：对 3 路按键各施加一次持续超过 DEBOUNCE_CYCLES 的稳定低电平按压; 对拨码 10 位各施加一次翻转; 逐周期采样 btn_pulse_o、btn_stable 语义与 sw_sync_o；结束：每次按压恰产生 1 个单周期脉冲；每次拨码翻转后 2 拍内 sw_sync_o 跟随
- `SCN-GLITCH`（input_ctrl）：前置：复位已释放; 按键处于释放态；激励：注入短毛刺（10 拍低）、中毛刺（DEBOUNCE_CYCLES/10 拍低）、边界毛刺（DEBOUNCE_CYCLES-1 拍低）三类干扰; 随后施加一次恰 DEBOUNCE_CYCLES 拍的稳定按压；结束：三类毛刺均不产生脉冲；随后的稳定按压恰产生 1 个脉冲（阈值边界精确）
- `SCN-SMOKE`（input_ctrl）：前置：testbench 直接例化 input_ctrl（集成路径冒烟：模块可被外部例化并观察全部端口）；激励：施加复位脉冲后做一次快速按压与拨码翻转; 观察全部输出端口；结束：端口行为符合预期且无 X/Z

### Oracles

- `ORC-PULSE-ONE`（input_ctrl）：每次稳定按压沿恰产生一个单周期脉冲；比较：脉冲总数与按压沿数相等，且每个脉冲宽度恰 1 个 clk_i 周期、相邻脉冲间隔 >= DEBOUNCE_CYCLES；时序窗：复位释放后的全程采样；失败判定：脉冲丢失、重复或宽度超过 1 拍
- `ORC-GLITCH-SUPPRESS`（input_ctrl）：短于阈值的低电平干扰不产生脉冲；比较：注入毛刺窗口内脉冲计数保持为零（毛刺类别含 10 拍、阈值/10 拍、阈值-1 拍三档）；时序窗：每类毛刺窗口及其后 DEBOUNCE_CYCLES 拍内；失败判定：任一毛刺触发脉冲
- `ORC-SW-SYNC`（input_ctrl）：拨码电平经 2 级同步后精确跟随；比较：sw_i 每次翻转后第 2 个上升沿起 sw_sync_o == sw_i；10 位全部覆盖；时序窗：每次拨码翻转后的连续 4 个采样点；失败判定：跟随延迟不等于 2 拍或出现毛刺
- `ORC-RESET-ZERO`（input_ctrl）：复位期间输出恒零；比较：每个采样点检查 btn_pulse_o==0 且 sw_sync_o==0；时序窗：rst_n_i==0 的每个 clk_i 上升沿采样点；失败判定：复位期间任何位非零

### Properties

- `PROP-PULSE-ONE`（input_ctrl）：当 按键从稳定释放态进入稳定按下态（经 DEBOUNCE_CYCLES 判定） 时，应满足 该判定拍 btn_pulse_o 对应位为 1 且仅持续 1 个 clk_i 周期；至少激活 3 次；观测信号：btn_i, db_cnt, btn_pulse_o
- `PROP-GLITCH-SUPPRESS`（input_ctrl）：当 低电平持续拍数 < DEBOUNCE_CYCLES 后回高 时，应满足 不产生任何脉冲（计数中途清零，稳定电平不变）；至少激活 3 次；观测信号：btn_i, db_cnt, btn_pulse_o
- `PROP-SW-SYNC`（input_ctrl）：当 sw_i 某位在第 t 拍翻转并保持 时，应满足 sw_sync_o 对应位最迟在第 t+2 拍起等于新电平；至少激活 10 次；观测信号：sw_i, sw_sync_o
- `PROP-RESET-ZERO`（input_ctrl）：当 rst_n_i == 0 时，应满足 btn_pulse_o == 3'b000 且 sw_sync_o == 10'b0；至少激活 1 次；观测信号：rst_n_i, btn_pulse_o, sw_sync_o

### Coverage

- `COV-BTNS`（input_ctrl）：3 路按键各产生过至少一次脉冲
- `COV-GLITCH-CLASS`（input_ctrl）：三类毛刺（短、中、阈值-1 边界）各注入过至少一次
- `COV-SW-ALL`（input_ctrl）：10 位拨码全部完成过一次翻转并被跟随

## 需求追踪

| 需求 | 模块 | 算法 | 场景 | Oracle | Property | 覆盖 |
|---|---|---|---|---|---|---|
| REQ-1 | input_ctrl | algo-debounce-pulse | SCN-PRESS | ORC-PULSE-ONE | PROP-PULSE-ONE | COV-BTNS |
| REQ-2 | input_ctrl | algo-debounce-pulse | SCN-GLITCH | ORC-GLITCH-SUPPRESS | PROP-GLITCH-SUPPRESS | COV-GLITCH-CLASS |
| REQ-3 | input_ctrl | algo-debounce-pulse | SCN-PRESS | ORC-SW-SYNC | PROP-SW-SYNC | COV-SW-ALL |
| REQ-4 | input_ctrl | algo-debounce-pulse | SCN-RESET | ORC-RESET-ZERO | PROP-RESET-ZERO | COV-BTNS |
