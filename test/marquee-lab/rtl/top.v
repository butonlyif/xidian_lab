`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: t20f256_xd_ps_eval_marquee
// 功能描述: t20f256-xd-ps-eval 直连板跑马灯顶层 —— 10 个用户 LED one-hot 轮流点亮
// 接口说明: clk_50m_i 50 MHz 输入时钟；arst_n_i 按键低有效复位；led_o[9:0] 用户 LED
// 设计约束: 引脚见 constraints/t20f256_xd_ps_eval_marquee.pins.isf；
//           STEP_CYCLES=6_250_000 → 8 Hz 步进（仿真可参数覆盖提速）
//============================================================================
module t20f256_xd_ps_eval_marquee #(
    parameter integer STEP_CYCLES = 6_250_000
) (
    input  wire       clk_50m_i,
    input  wire       arst_n_i,
    output wire [9:0] led_o
);
    led_marquee #(
        .LEDS        (10),
        .STEP_CYCLES (STEP_CYCLES)
    ) u_marquee (
        .clk_i   (clk_50m_i),
        .rst_n_i (arst_n_i),
        .led_o   (led_o)
    );
endmodule

`default_nettype wire
