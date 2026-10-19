`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: led_marquee
// 功能描述: 参数化 LED 跑马灯核 —— one-hot 循环左移，STEP_CYCLES 分频步进
// 接口说明: 单时钟域同步设计；led_o 为 one-hot 输出，步进节拍循环左移一位
// 设计约束: clk_i = 50 MHz；STEP_CYCLES = 6_250_000 时步进 8 Hz；
//           复位为异步有效、3 级同步器同步释放
//============================================================================
module led_marquee #(
    parameter int LEDS        = 10,
    parameter int STEP_CYCLES = 6_250_000
) (
    input  wire            clk_i,
    input  wire            rst_n_i,   // 异步低有效（板级按键），域内同步释放
    output wire [LEDS-1:0] led_o
);
    localparam int CNT_W = $clog2(STEP_CYCLES);

    // ---- 复位同步释放（3 级同步器，本域独立） -----------------------------
    reg [2:0] rst_sync_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) rst_sync_r <= 3'b000;
        else          rst_sync_r <= {rst_sync_r[1:0], 1'b1};
    end
    wire rst_n = rst_sync_r[2];

    // ---- 步进节拍（clock enable 语义，不分频时钟） ------------------------
    reg [CNT_W-1:0] cnt_r;
    wire step_tick = (cnt_r == CNT_W'(STEP_CYCLES - 1));

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)     cnt_r <= '0;
        else if (step_tick) cnt_r <= '0;
        else            cnt_r <= cnt_r + 1'b1;
    end

    // ---- one-hot 移位（数据与控制同一域，输出寄存） -----------------------
    reg [LEDS-1:0] led_r;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         led_r <= {{(LEDS-1){1'b0}}, 1'b1};
        else if (step_tick) led_r <= {led_r[LEDS-2:0], led_r[LEDS-1]};
        else                led_r <= led_r;
    end

    assign led_o = led_r;
endmodule

`default_nettype wire
