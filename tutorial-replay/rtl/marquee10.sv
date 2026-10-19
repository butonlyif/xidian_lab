`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: marquee10
// 功能描述: 参数化 one-hot 跑马灯核 —— 环形左移，STEP_CYCLES 时钟使能步进
// 接口说明: 单时钟域同步设计；led_bus_o 为 one-hot 输出，复位期间全零，
//           同步释放后 1 周期内出现初始码型（bit0 点亮）
// 设计约束: clk_i = 50 MHz；STEP_CYCLES = 6_250_000 时步进 8 Hz（125 ms/步）；
//           复位为异步断言、3 级同步器同步释放；不使用分频时钟
//============================================================================
module marquee10 #(
    parameter NUM_LEDS    = 10,
    parameter STEP_CYCLES = 6_250_000
) (
    input  wire                clk_i,
    input  wire                rst_n_i,    // 异步低有效（板级按键），域内同步释放
    output wire [NUM_LEDS-1:0] led_bus_o
);
    // ---- 复位同步释放（3 级同步器，本域独立） -----------------------------
    reg [2:0] rst_sync_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) rst_sync_r <= 3'b000;
        else          rst_sync_r <= {rst_sync_r[1:0], 1'b1};
    end
    wire rst_n = rst_sync_r[2];

    // ---- 步进节拍（clock enable 语义，不分频时钟） ------------------------
    reg [$clog2(STEP_CYCLES)-1:0] step_cnt;
    wire step_tick = (step_cnt == (STEP_CYCLES - 1));

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         step_cnt <= 0;
        else if (step_tick) step_cnt <= 0;
        else                step_cnt <= step_cnt + 1'b1;
    end

    // ---- one-hot 移位（数据与控制同域，输出寄存） -------------------------
    reg [NUM_LEDS-1:0] onehot_r;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         onehot_r <= {{(NUM_LEDS-1){1'b0}}, 1'b1};
        else if (step_tick) onehot_r <= {onehot_r[NUM_LEDS-2:0], onehot_r[NUM_LEDS-1]};
        else                onehot_r <= onehot_r;
    end

    // ---- 管脚输出寄存：REQ-2 复位期间全零，释放后 1 周期内出现初始码型 ----
    reg [NUM_LEDS-1:0] led_out_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) led_out_r <= {NUM_LEDS{1'b0}};
        else          led_out_r <= onehot_r;
    end

    assign led_bus_o = led_out_r;
endmodule

`default_nettype wire
