`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: t20f256_xd_ps_eval_stage0
// 功能描述: marquee-lab 集成顶层 —— 例化三个已验证模块：marquee10 跑马灯
//           （10 LED）、seg_display8 数码管扫描计数器（8 段 × 8 位）、
//           input_ctrl 按键消抖与拨码采样（BUT2 脉冲驱动蜂鸣器）
// 接口说明: clk_50m 板载时钟；arst_n 按键低有效复位；led_user* LED 输出；
//           seg_* 数码管段/位选；user_btn* 低有效按键；dip_sw* 拨码；buzzer
// 设计约束: 管脚见 constraints/t20f256_xd_ps_eval_stage0.pins.isf；
//           顶层只做例化与连线，逻辑全部在模块内；
//           sw_sync_o 通道本迭代未接负载（综合将裁剪，留待后续增量接线）
//============================================================================
module t20f256_xd_ps_eval_stage0 #(
    parameter STEP_CYCLES = 6_250_000
) (
    input  wire clk_50m,
    input  wire arst_n,
    output wire led_user,
    output wire led_user2,
    output wire led_user3,
    output wire led_user4,
    output wire led_user5,
    output wire led_user6,
    output wire led_user7,
    output wire led_user8,
    output wire led_user9,
    output wire led_user10,
    output wire seg_a,
    output wire seg_b,
    output wire seg_c,
    output wire seg_d,
    output wire seg_e,
    output wire seg_f,
    output wire seg_g,
    output wire seg_dp,
    output wire seg_sel1,
    output wire seg_sel2,
    output wire seg_sel3,
    output wire seg_sel4,
    output wire seg_sel5,
    output wire seg_sel6,
    output wire seg_sel7,
    output wire seg_sel8,
    input  wire user_btn2,
    input  wire user_btn3,
    input  wire user_btn4,
    input  wire dip_sw1,
    input  wire dip_sw2,
    input  wire dip_sw3,
    input  wire dip_sw4,
    input  wire dip_sw5,
    input  wire dip_sw6,
    input  wire dip_sw7,
    input  wire dip_sw8,
    input  wire dip_sw9,
    input  wire dip_sw10,
    output wire buzzer
);
    wire [9:0] led_bus;
    wire [7:0] seg_bus;      // {dp,g,f,e,d,c,b,a}
    wire [7:0] sel_bus;      // bit0=数位1 … bit7=数位8
    wire [2:0] btn_bus;      // bit0=BUT2（低有效）
    wire [9:0] sw_bus;       // bit0=SW1（上拨=1）
    wire [2:0] btn_pulse;
    wire [9:0] sw_sync;

    // ---- 增量一：10-LED one-hot 跑马灯（marquee-baseline 基线资产） --------
    marquee10 #(
        .NUM_LEDS    (10),
        .STEP_CYCLES (STEP_CYCLES)
    ) u_marquee (
        .clk_i     (clk_50m),
        .rst_n_i   (arst_n),
        .led_bus_o (led_bus)
    );

    // ---- 增量二：8 位数码管扫描计数器（seg-counter） -----------------------
    seg_display8 #(
        .TICK_CYCLES (50_000_000),
        .SCAN_CYCLES (50_000)
    ) u_seg_display8 (
        .clk_i   (clk_50m),
        .rst_n_i (arst_n),
        .seg_o   (seg_bus),
        .sel_o   (sel_bus)
    );

    // ---- 增量三：按键消抖脉冲 + 拨码同步（btn-switch） ---------------------
    input_ctrl #(
        .NUM_BTNS        (3),
        .NUM_SW          (10),
        .DEBOUNCE_CYCLES (1_000_000)
    ) u_input_ctrl (
        .clk_i       (clk_50m),
        .rst_n_i     (arst_n),
        .btn_i       (btn_bus),
        .sw_i        (sw_bus),
        .btn_pulse_o (btn_pulse),
        .sw_sync_o   (sw_sync)
    );

    // ---- 板级扇出：one-hot 灯总线逐位到 LED1..LED10（高电平点亮） ----------
    assign led_user   = led_bus[0];
    assign led_user2  = led_bus[1];
    assign led_user3  = led_bus[2];
    assign led_user4  = led_bus[3];
    assign led_user5  = led_bus[4];
    assign led_user6  = led_bus[5];
    assign led_user7  = led_bus[6];
    assign led_user8  = led_bus[7];
    assign led_user9  = led_bus[8];
    assign led_user10 = led_bus[9];

    // ---- 数码管段/位选扇出（段低有效，位选 one-hot 高有效） ----------------
    assign seg_a    = seg_bus[0];
    assign seg_b    = seg_bus[1];
    assign seg_c    = seg_bus[2];
    assign seg_d    = seg_bus[3];
    assign seg_e    = seg_bus[4];
    assign seg_f    = seg_bus[5];
    assign seg_g    = seg_bus[6];
    assign seg_dp   = seg_bus[7];
    assign seg_sel1 = sel_bus[0];
    assign seg_sel2 = sel_bus[1];
    assign seg_sel3 = sel_bus[2];
    assign seg_sel4 = sel_bus[3];
    assign seg_sel5 = sel_bus[4];
    assign seg_sel6 = sel_bus[5];
    assign seg_sel7 = sel_bus[6];
    assign seg_sel8 = sel_bus[7];

    // ---- 输入汇聚：按键低有效（bit0=BUT2），拨码上拨=1（bit0=SW1） ---------
    assign btn_bus = {user_btn4, user_btn3, user_btn2};
    assign sw_bus  = {dip_sw10, dip_sw9, dip_sw8, dip_sw7, dip_sw6,
                      dip_sw5,  dip_sw4, dip_sw3, dip_sw2, dip_sw1};

    // ---- 可视化：BUT2 每次有效按压（消抖脉冲）蜂鸣器短鸣一拍 ---------------
    assign buzzer = btn_pulse[0];
endmodule

`default_nettype wire
