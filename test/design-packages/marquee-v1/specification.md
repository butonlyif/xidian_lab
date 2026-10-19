# marquee-lab v1 -- 10-LED one-hot marquee on t20f256-xd-ps-eval

> 规格包：`marquee-v1@1`  
> 统一摘要：`6792268ec46d6e6c8ff0a717d9cee3b22e4b97cf486bc624894629b27fa5c1b0`

## 系统目标

第一个正式版本：在 t20f256-xd-ps-eval 评估板上以 50 MHz 系统时钟驱动 10 个用户 LED 的 one-hot 跑马灯，每秒 8 步循环，按键低有效异步复位。设计为单时钟域纯同步逻辑，复用 catalog marquee jacket 的硬件验证 RTL 基线。

## 需求与验收

| 需求 | 说明 | 验收条件 |
|---|---|---|
| REQ-001 | 复位行为：arst_n_i 低有效异步复位；复位释放后，跑马序列从 LED0（one-hot bit0）重新开始，计数器清零。 | 同步释放后首个采样点 led_o == 10'b0000000001；复位期间输出稳定无 X；同步释放经 3 级同步器（rst_sync_r[2]）。 |
| REQ-002 | 跑马主流程：任一时刻恰好 1 个 LED 点亮；每个步进节拍 one-hot 循环左移一位；50 MHz 下步进频率 8 Hz（STEP_CYCLES = 6_250_000）。 | 仿真（STEP_CYCLES 提速为 4）中每个采样点 popcount(led_o) == 1；相邻步进满足 rotate-left 关系；整圈 10 步。 |
| REQ-003 | 步进时序与边界：两次输出翻转之间恰好间隔 STEP_CYCLES 个时钟周期；led[9] -> led[0] 回绕发生在 led[9] 保持满 STEP_CYCLES 周期之后的下一个步进节拍；使用 clock enable 语义，不派生分频时钟。 | 翻转间隔计数 == STEP_CYCLES；回绕步满足同一关系；整圈周期 == 10 x STEP_CYCLES；无派生时钟。 |
| REQ-004 | 顶层集成：顶层 t20f256_xd_ps_eval_marquee 仅做端口直连例化 marquee 核；与板级约束（pins ISF：clk@H13、rst@A4、LED T8-R15，全部 3.3 V LVTTL/LVCMOS）一致；SDC 声明 20 ns 主时钟。 | 顶层+核心联合仿真连续完成 >= 2 整圈无挂起、led_o 无 X；引脚/电平与板卡 pin map 一致（板上观察为延期证据）。 |

## 系统组成与连接

### 系统框图

```mermaid
flowchart LR
    u_marquee[LED 跑马灯核心（one-hot 循环左移）]
    classDef reuse fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#1e4620
    classDef adapt fill:#fef7e0,stroke:#f9ab00,stroke-width:2px,color:#7a5b00
    classDef new fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6
    classDef ctrl fill:#f3e8fd,stroke:#a142f4,stroke-width:2px,stroke-dasharray:4 2,color:#5b1a7a
    class u_marquee new
```

### 实例与连接

| 实例 | 层级 | 物料状态 | 契约 |
|---|---|---|---|
| u_marquee | module | NEW | marquee-core |

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
| rst_board_n | clk_50m | active-low | 异步断言（板上按键 BUT1，arst_n_i@A4） | 同步释放：核内 3 级同步器 rst_sync_r，域内独立 |


## 物料来源与复用依据

### catalog marquee jacket RTL 基线（硬件验证）

对外可观察行为：50 MHz 时钟 + 低有效异步复位输入，10 位 one-hot LED 输出每 STEP_CYCLES 周期左移一位并回绕，复位释放后从 LED0 开始。

- 分类：`REUSE_UNCHANGED`
- 来源：catalog://boards/t20f256-xd-ps-eval/jackets/marquee（rtl/top.v + rtl/led_marquee.sv）（jacket 1.0.0 @ catalog 0.9.6 (commit a13abff)，许可：EvoVerse SDK catalog 物料（随 SDK 分发））
- 源摘要：`03aec0698e193f678e1624e4472dd0fa90dbf4a280852fca6aa70e3797061a8f`
- 使用原因：jacket 在同一板卡（t20f256-xd-ps-eval）上完成硬件验证（one-hot 跑马、8 Hz、按键复位），与本意图需求完全一致；重新生成无增益。工作区副本与 catalog 源逐字节一致（SHA-256 复核通过）。
- 证据适用范围：; ; 
- 适用配置：device=Trion T20F256（timing model C4）；board=t20f256-xd-ps-eval；clockHz=50000000；ledCount=10
- 失效条件：板卡 pin map 变更（LED/时钟/复位管脚移动）; LED 数量不是 10 或时钟不是 50 MHz（参数需重适配）; catalog jacket 基线升级且行为变化
- 集成检查：pins ISF 重放编译 PASS（create_* 注释的纯 pins 风格）; marquee-lab.peri.xml netlist 锁与当前工程名一致（改名后必须原生重建，见 review C-1）; SDC create_clock -period 20.000 与 clk_50m_i 端口名精确匹配

| 端口 | 方向 | 位宽 | 时钟域 | 复位域 |
|---|---|---|---|---|
| clk_50m_i | input | 1 | — | — |
| arst_n_i | input | 1 | — | — |
| led_o | output | 10 | — | — |

## 模块设计

### 参数化 LED 跑马灯核心

单时钟域 one-hot 循环左移跑马灯：以 clock-enable 计数器产生步进节拍（不分频时钟），驱动 LEDS 位 one-hot 寄存器每步左移一位并回绕；复位异步断言、3 级同步器同步释放。

**职责**

- 在 clk_i 域内产生周期为 STEP_CYCLES 的单周期步进节拍 step_tick（clock enable 语义）
- 维护 one-hot led_r 寄存器：复位值为 bit0 置位，每个 step_tick 循环左移一位（含 MSB->LSB 回绕）
- 对外部异步低有效复位做 3 级同步释放，域内使用同步释放后的 rst_n

**非职责**

- 管脚位置与 IO 电平分配（板级约束，由 pins ISF 承担）
- 时钟产生或 PLL（直接使用板级 50 MHz 时钟）
- 按键消抖（arst_n_i 直接作为异步复位输入）

**参数与约束**

| 参数 | 类型 | 默认值 | 约束 | 行为影响 |
|---|---|---|---|---|
| LEDS | integer | 10 | t20f256-xd-ps-eval 板固定为 10（用户 LED 数量） | one-hot 寄存器位宽与回绕点；板上对应 LED0-LED9 |
| STEP_CYCLES | integer | 6250000 | STEP_CYCLES = f_clk / f_step；50 MHz / 8 Hz = 6_250_000; 仿真提速时可参数覆盖（tb 取 4） | 步进节拍周期：每 STEP_CYCLES 个时钟周期 LED 左移一位 |

| 端口 | 方向 | 类型 | 位宽 | 时钟域 | 复位域 | 协议角色 | 空闲值 |
|---|---|---|---|---|---|---|---|
| clk_i | input | logic | 1 | clk_50m | rst_board_n | clock | — |
| rst_n_i | input | logic | 1 | clk_50m | rst_board_n | reset | — |
| led_o | output | logic | LEDS | clk_50m | rst_board_n | data | 10'b0000000001 |

**内部数据对象**

| 名称 | 作用 | 位宽 | 复位值 | 更新条件 | 所有权 |
|---|---|---|---|---|---|
| rst_sync_r | 复位同步链（3 级） | 3 | 3'b000（异步复位置零） | 每个 clk_i 上升沿左移入 1；bit2 即同步释放后的 rst_n | owned |
| cnt_r | 步进节拍计数器（clock enable） | 23 | 0 | 每个 clk_i 周期 +1；计满 STEP_CYCLES-1 后产生 step_tick 并清零（位宽 = $clog2(6_250_000) = 23） | owned |
| led_r | one-hot 显示寄存器（输出寄存） | LEDS | one-hot bit0 置位（{{(LEDS-1){1'b0}}, 1'b1}） | step_tick 时循环左移一位，否则保持 | owned |

**运行行为**

- 延迟：1 cycle
- 启动间隔：6250000 cycle
- 反压：无：自由运行的显示驱动输出，无 valid/ready 握手
- 错误处理：无错误态：one-hot 寄存器结构性合法，同步复位保证确定性初值

## 算法原理

## 验证策略

### Scenarios

- `SCEN-001`（marquee-core）：前置：arst_n_i 已断言（低电平）至少 3 个时钟周期; clk_i 稳定运行；激励：在任意序列中间重新断言 arst_n_i 并保持 3 周期; 释放 arst_n_i；结束：释放后观察到第一个 step_tick 步进
- `SCEN-002`（marquee-core）：前置：复位已释放; STEP_CYCLES 参数覆盖为 4（仿真提速）；激励：自由运行 clk_i，无其他激励；结束：连续观察到至少 3 个完整旋转周期
- `SCEN-003`（marquee-core）：前置：复位已释放; STEP_CYCLES = 4；激励：自由运行 clk_i；结束：包含至少 2 次 led[9]->led[0] 回绕的观察窗结束
- `SCEN-004`（marquee-core）：前置：顶层 t20f256_xd_ps_eval_marquee + led_marquee 联合编译通过；激励：施加 50 MHz 时钟与一次上电复位序列；结束：testbench 正常结束并打印结果标记

### Oracles

- `ORC-001`（marquee-core）：—；比较：精确相等：释放后第一个 clk_i 采样点逐位比对 led_o；时序窗：rst_sync_r[2] 上升后 1 个时钟周期内；失败判定：释放后首采样 led_o != 0x001，或复位期间 led_o 出现 X
- `ORC-002`（marquee-core）：—；比较：逐采样点不变式检查 + 相邻步进关系检查（one-hot 左移）；时序窗：整个观察窗（>= 3 个整圈）；失败判定：任一采样 popcount != 1，或相邻步进不满足循环左移关系
- `ORC-003`（marquee-core）：—；比较：事件间隔计数精确相等（含回绕步与整圈周期）；时序窗：>= 2 次 led[9]->led[0] 回绕；失败判定：任一翻转间隔 != STEP_CYCLES，或整圈周期 != 10 x STEP_CYCLES
- `ORC-004`（marquee-core）：—；比较：testbench 自检标记存在且为 PASS；全程无 X；时序窗：整个顶层联合仿真运行；失败判定：仿真超时/挂起、led_o 出现 X、或自检标记缺失/为 FAIL

### Properties

- `PROP-001`（marquee-core）：当 rst_sync_r[2] 上升（复位同步释放完成） 时，应满足 led_r == one-hot bit0; cnt_r == 0；至少激活 1 次；观测信号：rst_sync_r, led_o, cnt_r
- `PROP-002`（marquee-core）：当 复位释放后任意时钟周期 时，应满足 popcount(led_o) == 1；至少激活 10 次；观测信号：led_o
- `PROP-003`（marquee-core）：当 led_o 在周期 T 发生翻转 时，应满足 下一次翻转恰在 T + STEP_CYCLES 周期; 两翻转之间 led_o 保持不变；至少激活 10 次；观测信号：led_o, cnt_r

### Coverage

- `COV-001`（marquee-core）：FPGA_FUNCTIONAL 下覆盖率为延期证据（非阻塞）；冒烟场景 SCEN-004 的 2 整圈运行顺带满足全部 bin

## 需求追踪

| 需求 | 模块 | 算法 | 场景 | Oracle | Property | 覆盖 |
|---|---|---|---|---|---|---|
| REQ-001 | marquee-core |  | SCEN-001 | ORC-001 | PROP-001 |  |
| REQ-002 | marquee-core |  | SCEN-002 | ORC-002 | PROP-002 | COV-001 |
| REQ-003 | marquee-core |  | SCEN-003 | ORC-003 | PROP-003 |  |
| REQ-004 | marquee-core |  | SCEN-004 | ORC-004 |  | COV-001 |
