# 8 位数码管扫描计数器（seg-counter）

> 规格包：`marquee-lab-seg-counter@1.0.0`  
> 统一摘要：`717de32d27a5bd6998cefda176eaf34329ab7d3d55fc676ffc86c545329fa48d`

## 系统目标

在 marquee-baseline 基线之上建立第一个并行增量：驱动板上 2 片 FJ3461AH 数码管的 8 位十进制扫描计数器，每秒加一显示 00,000,000 到 99,999,999。全部逻辑运行在单一 50 MHz 时钟域，复位采用异步断言、同步释放，与基线共用时钟域与复位域。

## 需求与验收

| 需求 | 说明 | 验收条件 |
|---|---|---|
| REQ-1 | 复位释放后，8 位 BCD 级联十进制计数器从 00,000,000 起每 TICK_CYCLES 个 50 MHz 时钟周期（默认 50,000,000，即 1 秒）加一，到 99,999,999 后回绕到 00,000,000。 | 仿真（缩小 TICK_CYCLES）中观察到每个 tick 沿 BCD 计数值加一，最高位 9→0 时向低位无残留进位。 |
| REQ-2 | 复位有效（rst_n_i 拉低）期间数码管全灭：段输出 seg_o=8'hFF（低有效全灭）且位选 sel_o=8'h00（无任何位选通）。 | arst_n==0 的每个采样点 seg_o==8'hFF 且 sel_o==8'h00。 |
| REQ-3 | 位选扫描以 SCAN_CYCLES 个时钟周期（默认 50,000，即每位 1 ms）为节拍循环选通第 0..7 位，任一时刻恰有一位为高（one-hot），全帧刷新率 125 Hz。 | 每个采样点 sel_o 恰一位为 1；相邻选通变化间隔恰 SCAN_CYCLES 个周期；位序 0→1→…→7→0 循环。 |
| REQ-4 | 段输出 seg_o 为当前选通位 BCD 值的低有效段码（位序 {dp,g,f,e,d,c,b,a}，0→8'hC0 … 9→8'h90，dp 恒灭）。 | 扫描稳定窗口内对全部 10 个数字逐项核对 seg_o 与标准共阳段码表一致。 |

## 系统组成与连接

### 系统框图

```mermaid
flowchart LR
    u_seg_display8[数码管扫描计数器 seg_display8]
    classDef reuse fill:#e6f4ea,stroke:#34a853,stroke-width:2px,color:#1e4620
    classDef adapt fill:#fef7e0,stroke:#f9ab00,stroke-width:2px,color:#7a5b00
    classDef new fill:#e8f0fe,stroke:#4285f4,stroke-width:2px,color:#174ea6
    classDef ctrl fill:#f3e8fd,stroke:#a142f4,stroke-width:2px,stroke-dasharray:4 2,color:#5b1a7a
    class u_seg_display8 new
```

### 实例与连接

| 实例 | 层级 | 物料状态 | 契约 |
|---|---|---|---|
| u_seg_display8 | module | NEW | seg_display8 |

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
| rst_sys | clk_50m | active-low | asynchronous | 3-stage synchronizer |


## 物料来源与复用依据

### 板载数码管物料契约（2 片 FJ3461AH，8 段 × 8 位）

提供 8 段（a..dp）与 8 位选通的物理连接参考；本增量不改动板级顶层，仅在集成阶段扩展 ISF 管脚。

- 分类：`REFERENCE_ONLY`
- 来源：catalog/boards/t20f256-xd-ps-eval/pinout/t20f256-xd-ps-eval.csv（SEG_DIG、SEG_DIG_SEL1..8 行）（0.1.0，许可：EVOVERSE 板卡目录，随工程分发）
- 源摘要：`0000000000000000000000000000000000000000000000000000000000000000`
- 使用原因：管脚来自板卡 pin map 的 SEG_DIG（8 段）与 SEG_DIG_SEL1..8（8 位选通）接口组，全部 3.3 V bank，是数码管物料的唯一权威来源。
- 证据适用范围：板卡 pin map 解析：SEG_DIG 与 SEG_DIG_SEL1..8 共 16 管脚实证
- 适用配置：device=Trion T20F256（t20f256-xd-ps-eval）；ioStandard=3.3 V LVTTL / LVCMOS；segments=a=C6, b=C5, c=B7, d=C8, e=A9, f=B6, g=B5, dp=C7；digitSelects=sel1=A10, sel2=C10, sel3=C11, sel4=C9, sel5=C12, sel6=C13, sel7=C14, sel8=B9
- 失效条件：更换板卡导致数码管管脚映射变化; 驱动极性（共阳/共阴）或位选有效电平不同的板卡变体
- 集成检查：集成阶段 ISF 中 16 个数码管管脚均已 assign_pkg_pin 且 IO_STANDARD 为 3.3 V LVTTL / LVCMOS; 段与位选的极性假设与 DEC-SEG-LOW-ACTIVE / DEC-SEL-ONEHOT-HIGH 一致，若上板实测相反按决策记录取反

| 端口 | 方向 | 位宽 | 时钟域 | 复位域 |
|---|---|---|---|---|
| seg_pins_i | input | 8 | clk_50m | rst_sys |
| sel_pins_i | input | 8 | clk_50m | rst_sys |

## 模块设计

### 8 位数码管 BCD 扫描计数器

自由运行的十进制计数显示控制器：单一时钟域内用时钟使能产生 1 Hz 计数节拍与 1 kHz 扫描节拍，BCD 级联计数经段码查表与 one-hot 位选扫描输出到 2 片 FJ3461AH。

**职责**

- 在 clk_i 域内按 TICK_CYCLES 周期对 8 位 BCD 级联计数器加一（模 10 逐位进位）
- 按 SCAN_CYCLES 周期循环选通 8 个数位之一（one-hot 高有效）
- 把选通位的 BCD 值译码为低有效段码输出
- 复位期间段全灭、位选全零

**非职责**

- 不负责数码管管脚电气属性（IO_STANDARD、bank 电压由 ISF 约束管理）
- 不负责亮度控制（无 PWM）
- 不接收任何外部数据输入（自由计数）

**参数与约束**

| 参数 | 类型 | 默认值 | 约束 | 行为影响 |
|---|---|---|---|---|
| TICK_CYCLES | integer | 50000000 | TICK_CYCLES >= 2; 50_000_000 / TICK_CYCLES = 计数频率 Hz（默认 1 Hz） | 每个数位的保持时长：计数每 TICK_CYCLES 个时钟周期加一；仿真用小值提速 |
| SCAN_CYCLES | integer | 50000 | SCAN_CYCLES >= 8; 50_000_000 / (8*SCAN_CYCLES) = 全帧刷新率 Hz（默认 125 Hz） | 单个数位的选通时长；过小会引起闪烁、过大会闪烁可见，默认每位 1 ms |

| 端口 | 方向 | 类型 | 位宽 | 时钟域 | 复位域 | 协议角色 | 空闲值 |
|---|---|---|---|---|---|---|---|
| clk_i | input | clock | 1 | clk_50m | — | clock | — |
| rst_n_i | input | async-reset-active-low | 1 | clk_50m | rst_sys | reset | — |
| seg_o | output | logic | 8 | clk_50m | rst_sys | data | 复位期间 8'hFF（低有效段全灭） |
| sel_o | output | logic | 8 | clk_50m | rst_sys | data | 复位期间 8'h00（无任何位选通） |

**内部数据对象**

| 名称 | 作用 | 位宽 | 复位值 | 更新条件 | 所有权 |
|---|---|---|---|---|---|
| tick_cnt | 计数节拍分频计数器（clock enable 源） | clog2(TICK_CYCLES) | 0 | 每个 clk_i 上升沿 +1，达到 TICK_CYCLES-1 时回零并产生 tick 脉冲 | owned |
| scan_cnt | 扫描节拍分频计数器 | clog2(SCAN_CYCLES) | 0 | 每个 clk_i 上升沿 +1，达到 SCAN_CYCLES-1 时回零并产生 scan_tick 脉冲 | owned |
| scan_idx | 当前选通数位索引（0..7） | 3 | 0 | scan_tick 脉冲沿 +1（模 8） | owned |
| bcd_digits | 8 位 BCD 级联计数器（digit0 最低位，每位模 10 进位） | 32 | 0 | tick 脉冲沿最低位 +1，某位为 9 时回 0 并向高位进位 | owned |
| seg_code_r | 段码输出寄存器（查表结果寄存） | 8 | 255 | 每个 clk_i 上升沿按 scan_idx 选中的 BCD 位重新查表更新 | owned |

**运行行为**

- 延迟：0 cycle
- 启动间隔：1 cycle
- 反压：无——自由运行，无 valid/ready 握手
- 错误处理：无错误通路；复位有效期间输出恒为全灭/全零

## 算法原理

### BCD 级联计数 + one-hot 扫描 + 段码查表

用单一时钟域内的两个使能计数器分别产生计数节拍与扫描节拍，BCD 级联保证十进制语义，查表输出段码，避免任何分频时钟与运行时除法。

tick_cnt 每 TICK_CYCLES 周期回绕产生 tick；8 个 4 位 BCD 位在 tick 沿做模 10 级联加一。scan_cnt 每 SCAN_CYCLES 周期回绕推进 scan_idx（模 8 one-hot 位选）；每个时钟沿按 scan_idx 取对应 BCD 位查 10 项共阳段码表得到 seg_code_r。

**输入与输出**

| 方向 | 名称 | 类型 | 位宽 |
|---|---|---|---|
| 输入 | clk_i | clock-edge | 1 |
| 输入 | rst_n_i | async-reset | 1 |
| 输出 | seg_o | active-low-segment-bus | 8 |
| 输出 | sel_o | one-hot-digit-select | 8 |

**处理步骤**

1. 每个 clk_i 上升沿：tick_cnt 与 scan_cnt 各自 +1，分别在 TICK_CYCLES-1 / SCAN_CYCLES-1 处回零并置位对应使能脉冲
2. tick 脉冲沿：BCD 位 0 加一；某位为 9 时回 0 并让高位加一（级联进位），实现 00,000,000..99,999,999 循环
3. scan_tick 脉冲沿：scan_idx = (scan_idx + 1) mod 8，sel_o <= 1 << scan_idx（one-hot 高有效）
4. 每个 clk_i 上升沿：seg_code_r <= SEG_TABLE[bcd_digits[scan_idx]]（10 项常量查表，低有效段码，dp 恒灭）

**公式**

- `tick = (tick_cnt == TICK_CYCLES-1)`
- `scan_tick = (scan_cnt == SCAN_CYCLES-1)`
- `bcd_next[i] = tick ? (bcd[i]==9 ? 0 : bcd[i]+1) : bcd[i]，进位链 c[i+1] = tick && bcd[i]==9 && c[i]`
- `sel_next = 1'b1 << ((scan_idx + 1) mod 8)`
- `seg_o = SEG_TABLE[bcd_digits[scan_idx]]，SEG_TABLE = {C0,F9,A4,B0,99,92,82,F8,80,90}`

- 数值策略：signed=—；binaryPoint=0；intermediateWidth=32；overflow=wrap；truncation=none
- 时序：延迟 0 cycle；启动间隔 1 cycle
- 边界：99,999,999 的下一拍回绕到 00,000,000（最高位 9→0 且无越位进位残留）; scan_idx 7 的下一拍回到 0（one-hot 回绕）; 复位断言为异步，释放经 rst_sync 三级同步链；复位期间 seg_o=8'hFF、sel_o=8'h00
- 非法输入：复位有效时输出强制全灭；TICK_CYCLES>=2 与 SCAN_CYCLES>=8 由参数约束保证，计数器总会回绕，不存在未定义状态
- 参考模型：`count = (t // TICK_CYCLES) % 100000000; digits = [(count // 10**i) % 10 for i in range(8)]; sel = 1 << ((t // SCAN_CYCLES) % 8); seg = SEG_TABLE[digits[(t // SCAN_CYCLES) % 8]]`
- 容差：精确——数字逻辑，无数值容差

## 验证策略

### Scenarios

- `SCN-RESET`（seg_display8）：前置：上电，时钟自由运行; rst_n_i 保持为 0；激励：保持 rst_n_i=0 若干时钟周期，期间逐周期采样 seg_o 与 sel_o; 释放 rst_n_i 后再运行若干扫描周期；结束：复位期间 seg_o==8'hFF 且 sel_o==8'h00 成立；释放后一个扫描周期内出现正常扫描输出
- `SCN-COUNT`（seg_display8）：前置：复位已释放; 50 MHz 时钟自由运行（仿真用缩小的 TICK_CYCLES/SCAN_CYCLES）；激励：连续运行足够覆盖多位 BCD 递增与多轮扫描的时钟周期; 在每个 negedge 采样 BCD 值、sel_o 与 seg_o；结束：观察到 BCD 计数逐 tick 加一、位选按节拍循环且段码与表一致
- `SCN-WRAP`（seg_display8）：前置：复位已释放; BCD 计数被预置或推进到 99,999,999（仿真用极小 TICK_CYCLES）; scan_idx 推进到 7；激励：在 99,999,999→00,000,000 回绕沿与 scan_idx 7→0 回绕沿前后逐周期检查; 检查回绕沿恰好只加一次且无越位进位残留；结束：计数回绕后 BCD 值为全零、扫描位序回到 0，无重复步进或丢步
- `SCN-SMOKE`（seg_display8）：前置：testbench 直接例化 seg_display8（集成路径冒烟：模块可被外部例化并观察全部端口）；激励：对模块施加复位脉冲后自由运行少量扫描周期; 观察 seg_o/sel_o 端口行为；结束：端口在复位后呈现稳定扫描序列，无 X/Z

### Oracles

- `ORC-COUNT-INC`（seg_display8）：每个 tick 沿 BCD 计数值恰好加一（十进制语义）；比较：把 8×4bit BCD 拼成整数与期望值 (prev+1) mod 100000000 比较；时序窗：每个 tick 使能脉冲沿；失败判定：跳变超过 +1、不变、或出现非 BCD 码（某位 >9）
- `ORC-RESET-BLANK`（seg_display8）：复位有效期间数码管全灭；比较：每个采样点检查 seg_o==8'hFF 且 sel_o==8'h00；时序窗：rst_n_i==0 的每个 clk_i 上升沿采样点；失败判定：复位期间任何段被点亮或任何位被选通
- `ORC-SCAN-ROUND`（seg_display8）：位选扫描 one-hot、节拍精确、位序循环；比较：sel_o 汉明权重恒为 1；相邻变化间隔恰 SCAN_CYCLES 个周期；位序按 0→1→…→7→0；时序窗：复位释放后的每个采样点及相邻选通变化沿；失败判定：多位同选、漏选、间隔不等于 SCAN_CYCLES 或位序错乱
- `ORC-SEG-DECODE`（seg_display8）：段码等于选通位 BCD 值的标准共阳段码；比较：扫描稳定窗口内 seg_o 与 SEG_TABLE[digit[scan_idx]] 逐项比较（覆盖 0..9 全部数字）；时序窗：每个数位选通稳定后的采样点；失败判定：任一数字的段码与表不符

### Properties

- `PROP-COUNT-INC`（seg_display8）：当 tick 使能脉冲沿（复位已释放） 时，应满足 BCD 计数值 = (prev + 1) mod 100000000，每位保持合法 BCD（0..9）；至少激活 10 次；观测信号：tick_cnt, bcd_digits
- `PROP-RESET-BLANK`（seg_display8）：当 rst_n_i == 0 时，应满足 seg_o == 8'hFF 且 sel_o == 8'h00；至少激活 1 次；观测信号：rst_n_i, seg_o, sel_o
- `PROP-SCAN-HOLD`（seg_display8）：当 复位已释放且 scan_cnt 未回绕 时，应满足 sel_o 保持不变；回绕沿变为下一位（模 8）；任一时刻恰一位为高；至少激活 8 次；观测信号：scan_cnt, sel_o
- `PROP-SEG-DECODE`（seg_display8）：当 选通位 BCD 值为 d（d ∈ 0..9）且选通已稳定 时，应满足 seg_o == SEG_TABLE[d]；至少激活 10 次；观测信号：bcd_digits, scan_idx, seg_o

### Coverage

- `COV-DIGITS`（seg_display8）：数字 0..9 全部至少显示过一次
- `COV-SCAN-POS`（seg_display8）：8 个数位全部被选通过至少一次

## 需求追踪

| 需求 | 模块 | 算法 | 场景 | Oracle | Property | 覆盖 |
|---|---|---|---|---|---|---|
| REQ-1 | seg_display8 | algo-bcd-scan | SCN-COUNT | ORC-COUNT-INC | PROP-COUNT-INC | COV-DIGITS |
| REQ-2 | seg_display8 | algo-bcd-scan | SCN-RESET | ORC-RESET-BLANK | PROP-RESET-BLANK | COV-SCAN-POS |
| REQ-3 | seg_display8 | algo-bcd-scan | SCN-COUNT | ORC-SCAN-ROUND | PROP-SCAN-HOLD | COV-SCAN-POS |
| REQ-4 | seg_display8 | algo-bcd-scan | SCN-SMOKE | ORC-SEG-DECODE | PROP-SEG-DECODE | COV-DIGITS |
