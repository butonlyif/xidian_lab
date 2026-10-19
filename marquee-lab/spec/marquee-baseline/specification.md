# 10-LED 跑马灯基线（marquee-baseline）

> 规格包：`marquee-lab-marquee-baseline@1.0.0`  
> 统一摘要：`ef9a502bbb14fa8edcdcc5ca53b9fd24074c2c9303d0e958238448d40eba7da8`

## 系统目标

在 t20f256-xd-ps-eval 板卡的 stage0 骨架之上建立首个受管基线设计：一个 10 位 one-hot 跑马灯，作为 EvoVerse 全流程教程的启动基线。逻辑全部运行在单一 50 MHz 时钟域，复位采用异步断言、同步释放。

## 需求与验收

| 需求 | 说明 | 验收条件 |
|---|---|---|
| REQ-1 | 复位释放后，10 个用户 LED 按 one-hot 跑马灯样式循环点亮，步进频率 8 Hz（每步 125 ms）。 | 仿真中观察到点亮位按 0→1→…→9→0 环形推进，每步间隔 STEP_CYCLES=6,250,000 个 50 MHz 时钟周期。 |
| REQ-2 | 复位有效（arst_n 拉低）期间所有 LED 熄灭。 | arst_n==0 的每个采样点 led_bus_o==0；释放后一个时钟周期内出现初始 one-hot 码型。 |
| REQ-3 | 步进时序由 STEP_CYCLES 参数精确决定，不使用分频时钟驱动逻辑。 | 相邻两次步进之间恰好间隔 STEP_CYCLES 个 clk_i 周期；全部逻辑运行在单一 50 MHz 时钟域（clock enable 风格）。 |
| REQ-4 | 跑马灯输出经 stage0 板级顶层到达 10 个物理 LED 管脚。 | 顶层例化 u_marquee，并把 10 位灯总线映射到 led_user..led_user10 十个管脚；新增 ISF 约束全部重放安全（仅 set_property / assign_pkg_pin）。 |

## 系统组成与连接

### 系统框图

```mermaid
flowchart LR
    u_marquee[跑马灯 marquee10]
    u_stage0_top[(stage0 板级顶层)]
    u_marquee -->|onehot-parallel-bus| u_stage0_top
    classDef reuse fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#1e4620
    classDef adapt fill:#fef7e0,stroke:#f9ab00,stroke-width:2px,color:#7a5b00
    classDef new fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6
    classDef ctrl fill:#f3e8fd,stroke:#a142f4,stroke-width:2px,stroke-dasharray:4 2,color:#5b1a7a
    class u_marquee new
    class u_stage0_top adapt
```

### 实例与连接

| 实例 | 层级 | 物料状态 | 契约 |
|---|---|---|---|
| u_marquee | module | NEW | marquee10 |
| u_stage0_top | system | ADAPT_REQUIRED | mat-stage0-top |

| 连接 | 源 | 目标 | 协议 | 类型 | 拓扑 | CDC 策略 |
|---|---|---|---|---|---|---|
| c-led-bus | u_marquee.led_bus_o | u_stage0_top.led_bus_i | onehot-parallel-bus | data | chain | single-domain |

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

### stage0 板级顶层骨架（clk_50m / arst_n / led_user 管脚映射）

提供板级时钟与复位入口、10 个用户 LED 管脚出口；接纳 marquee10 例化并把灯总线扇出到管脚。

- 分类：`ADAPT_REQUIRED`
- 来源：rtl/top.v（stage0 skeleton，t20f256_xd_ps_eval_stage0）（1.0.0，许可：EVOVERSE SDK 教程样例，随工程分发）
- 源摘要：`839e5208e63620f5b98a010b8f648e8d22ad342853ae3c767b9b5aeb6804a7d0`
- 使用原因：stage0 已在真实工具链上四阶段编译 PASS（map/pnr/pgm），管脚 H13/A4/T8 落针实证，是本工程最可信的板级物料。
- 证据适用范围：stage0 编译（2026-10-16）：efx_map / efx_pnr / efx_pgm 全 PASS，H13/A4/T8 落针与 Fmax 399.521 MHz 实证
- 适用配置：device=Trion T20F256（t20f256-xd-ps-eval）；ioStandard=3.3 V LVTTL / LVCMOS；ledPolarity=high-level-lights；clockSource=50 MHz 板载晶振 @ H13
- 失效条件：更换板卡或载体导致管脚映射变化（ISF 引脚分配不同）; LED 极性改为低电平点亮的板卡变体; 时钟源频率不再是 50 MHz
- 集成检查：输入端口 led_bus_i（10 位）由 u_marquee.led_bus_o 驱动，顶层内部把 10 位总线逐位映射到 led_user..led_user10 十个输出管脚; 顶层例化 u_stage0_top 的端口名与本契约 ports 完全一致; ISF 中 led_user..led_user10 十个管脚均已 assign_pkg_pin 且 IO_STANDARD 为 3.3 V LVTTL / LVCMOS; 编译后 pinout.rpt 中无管脚冲突，clk_50m=H13、arst_n=A4 保持不变

| 端口 | 方向 | 位宽 | 时钟域 | 复位域 |
|---|---|---|---|---|
| led_bus_i | input | 10 | clk_50m | rst_sys |
| clk_50m | input | 1 | clk_50m | — |
| arst_n | input | 1 | — | rst_sys |
| led_user | output | 1 | clk_50m | rst_sys |
| led_user2 | output | 1 | clk_50m | rst_sys |
| led_user3 | output | 1 | clk_50m | rst_sys |
| led_user4 | output | 1 | clk_50m | rst_sys |
| led_user5 | output | 1 | clk_50m | rst_sys |
| led_user6 | output | 1 | clk_50m | rst_sys |
| led_user7 | output | 1 | clk_50m | rst_sys |
| led_user8 | output | 1 | clk_50m | rst_sys |
| led_user9 | output | 1 | clk_50m | rst_sys |
| led_user10 | output | 1 | clk_50m | rst_sys |

## 模块设计

### 10 位 one-hot 跑马灯

自由运行的循环灯控制器：在单一时钟域内用时钟使能分频产生 8 Hz 步进，输出 10 位 one-hot 灯总线，复位期间输出全零。

**职责**

- 在 clk_i 域内按 STEP_CYCLES 周期步进 one-hot 灯位（环形左移）
- 复位有效期间强制 led_bus_o 全零，释放后从最低位点亮开始
- 通过 NUM_LEDS / STEP_CYCLES 参数化灯数与步进周期

**非职责**

- 不负责 LED 管脚电气属性（IO_STANDARD、bank 电压由 ISF 约束管理）
- 不负责按键、拨码等其他板级外设
- 不产生任何握手或背压信号（自由运行）

**参数与约束**

| 参数 | 类型 | 默认值 | 约束 | 行为影响 |
|---|---|---|---|---|
| NUM_LEDS | integer | 10 | 1 <= NUM_LEDS <= 32 | 决定 led_bus_o 位宽与环形长度；本基线固定例化为 10 |
| STEP_CYCLES | integer | 6250000 | STEP_CYCLES >= 1; 50_000_000 / STEP_CYCLES = 8 → 每步 125 ms | 每盏灯点亮 STEP_CYCLES 个时钟周期；默认值对应 50 MHz 下 8 Hz 步进 |

| 端口 | 方向 | 类型 | 位宽 | 时钟域 | 复位域 | 协议角色 | 空闲值 |
|---|---|---|---|---|---|---|---|
| clk_i | input | clock | 1 | clk_50m | — | clock | — |
| rst_n_i | input | async-reset-active-low | 1 | clk_50m | rst_sys | reset | — |
| led_bus_o | output | logic | NUM_LEDS | clk_50m | rst_sys | data | 复位期间全零；运行期间 one-hot |

**内部数据对象**

| 名称 | 作用 | 位宽 | 复位值 | 更新条件 | 所有权 |
|---|---|---|---|---|---|
| step_cnt | 步进分频计数器（clock enable 源） | clog2(STEP_CYCLES) | 0 | 每个 clk_i 上升沿 +1，达到 STEP_CYCLES-1 时回零 | owned |
| onehot_r | one-hot 灯位寄存器（输出寄存） | NUM_LEDS | {(NUM_LEDS-1)'b0, 1'b1}（仅最低位为 1） | step_cnt 回绕沿环形左移一位 | owned |

**运行行为**

- 延迟：0 cycle
- 启动间隔：1 cycle
- 反压：无——自由运行，无 valid/ready 握手
- 错误处理：无错误通路；复位有效期间输出恒为全零

## 算法原理

### one-hot 环形左移（时钟使能步进）

用单一时钟域内的使能计数器产生均匀步进，并把 one-hot 码型环形推进，避免任何分频时钟。

N 位寄存器仅一位为 1；使能计数器每 STEP_CYCLES 周期回绕一次，回绕沿把 1 从 bit i 移到 bit (i+1) mod N；复位把 1 归位到 bit 0 且其余清零。

**输入与输出**

| 方向 | 名称 | 类型 | 位宽 |
|---|---|---|---|
| 输入 | clk_i | clock-edge | 1 |
| 输入 | rst_n_i | async-reset | 1 |
| 输出 | led_bus_o | one-hot-vector | NUM_LEDS |

**处理步骤**

1. 每个 clk_i 上升沿：若 !rst_n_i，step_cnt 与 onehot_r 同步清零（onehot_r 仅保留 bit0）
2. 否则 step_cnt+1；当 step_cnt==STEP_CYCLES-1 时回零并置位使能脉冲
3. 使能脉冲有效时：onehot_r <= {onehot_r[NUM_LEDS-2:0], onehot_r[NUM_LEDS-1]}，实现环形左移

**公式**

- `step_cnt_next = (step_cnt == STEP_CYCLES-1) ? 0 : step_cnt + 1`
- `step_en = (step_cnt == STEP_CYCLES-1)`
- `onehot_r_next = rst_n_i ? (step_en ? {onehot_r[NUM_LEDS-2:0], onehot_r[NUM_LEDS-1]} : onehot_r) : {{(NUM_LEDS-1){1'b0}}, 1'b1}`
- `led_bus_o = onehot_r`

- 数值策略：signed=—；binaryPoint=0；intermediateWidth=NUM_LEDS；overflow=wrap；truncation=none
- 时序：延迟 0 cycle；启动间隔 1 cycle
- 边界：step_cnt==STEP_CYCLES-1 的回绕沿恰好每 STEP_CYCLES 周期出现一次; 最高位灯位经环形回到最低位（bit NUM_LEDS-1 → bit 0）; 复位断言为异步，释放经 rst_sync 三级同步链
- 非法输入：复位有效时输出强制全零；STEP_CYCLES>=1 由参数约束保证，计数器总会回绕，不存在未定义状态
- 参考模型：`pos = (t // STEP_CYCLES) % NUM_LEDS; led = [1 if i == pos else 0 for i in range(NUM_LEDS)]`
- 容差：精确——数字逻辑，无数值容差

## 验证策略

### Scenarios

- `SCN-RESET`（marquee10）：前置：上电，时钟自由运行; arst_n 保持为 0；激励：保持 arst_n=0 若干时钟周期，期间逐周期采样 led_bus_o; 释放 arst_n（拉高），再运行若干周期；结束：复位期间 led_bus_o==0 成立，释放后一个周期内出现初始 one-hot 码型
- `SCN-MAINFLOW`（marquee10）：前置：复位已释放; 50 MHz 时钟自由运行；激励：连续运行 >= (NUM_LEDS+2)*STEP_CYCLES 个时钟周期（仿真中使用缩小后的 STEP_CYCLES 以控制时长）；结束：观察到点亮位完成至少一个完整的 0→1→…→9→0 环
- `SCN-BOUNDARY`（marquee10）：前置：复位已释放; step_cnt 接近 STEP_CYCLES-1；激励：在 step_cnt==STEP_CYCLES-1 边界前后逐周期检查：回绕前 led_bus_o 保持、回绕沿恰好步进一次；结束：相邻两次步进之间恰好间隔 STEP_CYCLES 个周期，边界无重复步进或丢步
- `SCN-SMOKE`（marquee10）：前置：顶层已例化 u_marquee 并把 10 位灯总线映射到 led_user..led_user10；激励：对顶层施加 clk_50m 与 arst_n 复位脉冲; 释放复位后运行少量步进周期；结束：顶层 10 个 LED 输出端口整体呈现 one-hot 序列且随步进推进

### Oracles

- `ORC-RESET-ZERO`（marquee10）：复位有效期间 led_bus_o 恒为全零；比较：每个采样点检查 led_bus_o == 0；时序窗：arst_n==0 的每个 clk_i 上升沿采样点；失败判定：复位期间任意一位为 1
- `ORC-ONEHOT`（marquee10）：复位释放后任意时刻 led_bus_o 恰有一位为 1；比较：对 led_bus_o 做 one-hot 检查（计 1 的个数 == 1）；时序窗：复位释放后的每个 clk_i 上升沿采样点；失败判定：全零或多位为 1
- `ORC-SEQUENCE`（marquee10）：点亮位置按 i → (i+1) mod NUM_LEDS 顺序推进；比较：记录每次步进后的位置序列，与预期环形序列逐项比较；时序窗：每次 step_cnt 回绕沿；失败判定：位置跳变、倒退或重复
- `ORC-STEP-PERIOD`（marquee10）：相邻两次步进之间恰好间隔 STEP_CYCLES 个时钟周期；比较：对步进沿之间的周期计数，与 STEP_CYCLES 精确相等；时序窗：任意相邻两次步进沿之间；失败判定：步进间隔不等于 STEP_CYCLES

### Properties

- `PROP-RESET`（marquee10）：当 arst_n == 0 时，应满足 led_bus_o == 0；至少激活 1 次；观测信号：arst_n, led_bus_o
- `PROP-ONEHOT`（marquee10）：当 arst_n == 1（复位释放后每个采样点） 时，应满足 led_bus_o 恰有一位为 1；至少激活 10 次；观测信号：led_bus_o
- `PROP-ROTATE`（marquee10）：当 step_cnt 回绕沿（step_en 有效） 时，应满足 led_bus_o 环形左移一位：pos_next = (pos + 1) % NUM_LEDS；至少激活 10 次；观测信号：step_cnt, led_bus_o
- `PROP-HOLD`（marquee10）：当 复位已释放且 step_cnt 未回绕 时，应满足 led_bus_o 保持不变；至少激活 5 次；观测信号：step_cnt, led_bus_o

### Coverage

- `COV-STATES`（marquee10）：全部 NUM_LEDS=10 个点亮位置各被点亮至少一次
- `COV-RESET`（marquee10）：复位断言期与复位释放后的行为各被观察至少一次

## 需求追踪

| 需求 | 模块 | 算法 | 场景 | Oracle | Property | 覆盖 |
|---|---|---|---|---|---|---|
| REQ-1 | marquee10 | algo-onehot-rotate | SCN-MAINFLOW | ORC-ONEHOT, ORC-SEQUENCE | PROP-ONEHOT, PROP-ROTATE | COV-STATES |
| REQ-2 | marquee10 | algo-onehot-rotate | SCN-RESET | ORC-RESET-ZERO | PROP-RESET | COV-RESET |
| REQ-3 | marquee10 | algo-onehot-rotate | SCN-BOUNDARY | ORC-STEP-PERIOD | PROP-HOLD | COV-STATES |
| REQ-4 | marquee10 |  | SCN-SMOKE | ORC-ONEHOT | PROP-ONEHOT | COV-STATES |
