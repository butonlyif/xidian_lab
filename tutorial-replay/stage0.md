---
ws_manifest_version: 2
kind: jacket
id: stage0
display_name: T20F256-Eval Stage-0 Skeleton
version: 1.0.0
status: active
belongs_to_board: t20f256-xd-ps-eval
delivery: project-snapshot
project_file: t20f256-xd-ps-eval-stage0.xml
---

[English](stage0.en.md) | 中文

# Stage-0 — t20f256-xd-ps-eval 骨架工程

`stage0` 是 EvoVerse SDK（`evoverse new-project`）为 [t20f256-xd-ps-eval](../../t20f256-xd-ps-eval.md) 生成的最小可运行工程：一个 LED 闪烁设计，只占用时钟、复位、LED 三类骨架信号，用于在上手阶段打通「工程生成 → 综合 → 布局布线 → 烧录 → 板上观察」的完整链路。

## 硬件资源占用

| 信号 | 方向 | 管脚 | 电平 | 板上资源 |
|---|---|---|---|---|
| `clk_50m` | in | H13 | 3.3 V LVTTL/LVCMOS | 50 MHz 系统时钟 |
| `arst_n` | in | A4 | 3.3 V LVTTL/LVCMOS | 低有效复位按键 |
| `led_user` | out | T8 | 3.3 V LVTTL/LVCMOS | 用户 LED |

涉及的 7 个 IO bank（1A、1B_1C、1D_1E、3A_3B_3C、3D_3E、4A、4B）电压全部为 3.3 V。管脚与电平来自板卡 pin map 的自动解析，与 [t20f256-xd-ps-eval.md](../../t20f256-xd-ps-eval.md) 中的 stage-0 骨架信号一致。

## 设计说明

`rtl/top.v`（顶层 `t20f256_xd_ps_eval_stage0`）为纯同步单域逻辑：

- 24 位计数器在 `clk_50m` 上升沿计数，`arst_n` 异步清零；
- 计数器最高位 `cnt[23]` 直接驱动 `led_user`，50 MHz 下约 0.34 s 完成一个闪烁周期。

无 PLL、无其他 IP 依赖，是可用于复核工具链与板卡健康状态的最小负载。

## 文件清单与生成方式

```text
stage0/
├── rtl/top.v                          # 骨架 RTL（自动生成）
├── constraints/
│   ├── t20f256_xd_ps_eval_stage0.pins.isf   # 管脚与 bank 电压（自动生成）
│   └── t20f256_xd_ps_eval_stage0.sdc        # 主时钟约束（自动生成）
└── t20f256-xd-ps-eval-stage0.xml            # Efinity 2026.1 工程（自动生成）
```

全部文件由 SDK 从板卡 pin map 生成，**不要手工编辑**。时序约束仅声明主时钟：`create_clock -name clk_50m -period 20.000 [get_ports clk_50m]`。

如需调整管脚，应修改板卡 pin map（`pinout/t20f256-xd-ps-eval.csv` 及其上游定义）后重新生成；如需承载真实功能，请新建 jacket（参考 [marquee](../marquee/marquee.md) 的结构），而不是修改 stage0。

## 编译与烧录

1. 使用 Efinity 2026.1 打开 `t20f256-xd-ps-eval-stage0.xml`。
2. 依次执行 Synthesis → Place & Route → Generate Bitstream。
3. 烧录后上电，观察到用户 LED 以约 0.34 s 周期闪烁即为通过；若 LED 不亮，优先用本工程排查时钟、复位极性与 LED 管脚映射。
