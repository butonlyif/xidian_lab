`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: input_ctrl
// 功能描述: 按键消抖脉冲 + 拨码同步采样 —— 按键两级同步 + 稳定计数消抖，
//           每次按下沿恰一个单周期脉冲；拨码两级同步直采电平
// 接口说明: btn_i 低有效（板载上拉）；sw_i 上拨=1；btn_pulse_o 单周期高脉冲
// 设计约束: clk_i = 50 MHz；DEBOUNCE_CYCLES=1M → 20 ms 阈值；
//           复位异步断言、3 级同步释放；同步链标注 ASYNC_REG
//============================================================================
module input_ctrl #(
    parameter NUM_BTNS         = 3,
    parameter NUM_SW           = 10,
    parameter DEBOUNCE_CYCLES  = 1_000_000
) (
    input  wire               clk_i,
    input  wire               rst_n_i,    // 异步低有效（板级按键），域内同步释放
    input  wire [NUM_BTNS-1:0] btn_i,
    input  wire [NUM_SW-1:0]  sw_i,
    output wire [NUM_BTNS-1:0] btn_pulse_o,
    output wire [NUM_SW-1:0]  sw_sync_o
);
    // ---- 复位同步释放（3 级同步器，本域独立） -----------------------------
    reg [2:0] rst_sync_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) rst_sync_r <= 3'b000;
        else          rst_sync_r <= {rst_sync_r[1:0], 1'b1};
    end
    wire rst_n = rst_sync_r[2];

    // ---- 按键两级同步链（ASYNC_REG；初值释放态全 1） ----------------------
    (* ASYNC_REG = "TRUE" *) reg [NUM_BTNS-1:0] btn_sync1, btn_sync2;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) {btn_sync2, btn_sync1} <= {2*NUM_BTNS{1'b1}};
        else        {btn_sync2, btn_sync1} <= {btn_sync1, btn_i};
    end

    // ---- 稳定计数消抖：与已接受电平不同则累计，相同则清零 -----------------
    reg [$clog2(DEBOUNCE_CYCLES)-1:0] db_cnt;
    reg [NUM_BTNS-1:0] btn_stable;
    wire differ = (btn_sync2 != btn_stable);
    wire deb_done = (db_cnt == (DEBOUNCE_CYCLES - 1));
    wire accept = differ && deb_done;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            db_cnt     <= 0;
            btn_stable <= {NUM_BTNS{1'b1}};
        end else if (accept) begin
            db_cnt     <= 0;
            btn_stable <= btn_sync2;
        end else if (differ) begin
            db_cnt <= db_cnt + 1'b1;
        end else begin
            db_cnt <= 0;
        end
    end

    // ---- 脉冲：接受拍且新稳定为按下、旧稳定为释放（管脚寄存，复位为 0） ---
    wire [NUM_BTNS-1:0] press_edge = btn_stable & ~btn_sync2;
    reg [NUM_BTNS-1:0] pulse_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) pulse_r <= {NUM_BTNS{1'b0}};
        else          pulse_r <= accept ? press_edge : {NUM_BTNS{1'b0}};
    end
    assign btn_pulse_o = pulse_r;

    // ---- 拨码两级同步链（直接输出第 2 级，复位期间为 0） ------------------
    (* ASYNC_REG = "TRUE" *) reg [NUM_SW-1:0] sw_sync1, sw_sync2;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) {sw_sync2, sw_sync1} <= {2*NUM_SW{1'b0}};
        else          {sw_sync2, sw_sync1} <= {sw_sync1, sw_i};
    end
    assign sw_sync_o = sw_sync2;
endmodule

`default_nettype wire
