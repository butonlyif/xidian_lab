`default_nettype none
`timescale 1ns / 1ps

//============================================================================
// 模块名称: seg_display8
// 功能描述: 8 位数码管 BCD 扫描计数器 —— 1 Hz 十进制计数 + 1 ms/位扫描 +
//           低有效段码查表（共阳），复位期间全灭
// 接口说明: 单时钟域同步设计；seg_o={dp,g,f,e,d,c,b,a} 低有效；sel_o one-hot 高有效
// 设计约束: clk_i = 50 MHz；TICK_CYCLES=50M → 1 Hz 计数；SCAN_CYCLES=50K →
//           每位 1 ms（全帧 125 Hz）；复位异步断言、3 级同步释放
//============================================================================
module seg_display8 #(
    parameter TICK_CYCLES = 50_000_000,
    parameter SCAN_CYCLES = 50_000
) (
    input  wire       clk_i,
    input  wire       rst_n_i,    // 异步低有效（板级按键），域内同步释放
    output wire [7:0] seg_o,
    output wire [7:0] sel_o
);
    // ---- 复位同步释放（3 级同步器，本域独立） -----------------------------
    reg [2:0] rst_sync_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) rst_sync_r <= 3'b000;
        else          rst_sync_r <= {rst_sync_r[1:0], 1'b1};
    end
    wire rst_n = rst_sync_r[2];

    // ---- 计数节拍（clock enable 语义，不分频时钟） ------------------------
    reg [$clog2(TICK_CYCLES)-1:0] tick_cnt;
    wire tick = (tick_cnt == (TICK_CYCLES - 1));
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)    tick_cnt <= 0;
        else if (tick) tick_cnt <= 0;
        else           tick_cnt <= tick_cnt + 1'b1;
    end

    // ---- 扫描节拍与位索引 -------------------------------------------------
    reg [$clog2(SCAN_CYCLES)-1:0] scan_cnt;
    wire scan_tick = (scan_cnt == (SCAN_CYCLES - 1));
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         scan_cnt <= 0;
        else if (scan_tick) scan_cnt <= 0;
        else                scan_cnt <= scan_cnt + 1'b1;
    end

    reg [2:0] scan_idx;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         scan_idx <= 3'd0;
        else if (scan_tick) scan_idx <= scan_idx + 1'b1;   // 模 8 自然回绕
    end

    // ---- 8 位 BCD 级联计数（每位模 10 逐级进位） ---------------------------
    reg [3:0] d0, d1, d2, d3, d4, d5, d6, d7;
    wire en0 = tick;
    wire co0 = en0 && d0 == 4'd9;
    wire en1 = co0;
    wire co1 = en1 && d1 == 4'd9;
    wire en2 = co1;
    wire co2 = en2 && d2 == 4'd9;
    wire en3 = co2;
    wire co3 = en3 && d3 == 4'd9;
    wire en4 = co3;
    wire co4 = en4 && d4 == 4'd9;
    wire en5 = co4;
    wire co5 = en5 && d5 == 4'd9;
    wire en6 = co5;
    wire co6 = en6 && d6 == 4'd9;
    wire en7 = co6;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            d0 <= 4'd0; d1 <= 4'd0; d2 <= 4'd0; d3 <= 4'd0;
            d4 <= 4'd0; d5 <= 4'd0; d6 <= 4'd0; d7 <= 4'd0;
        end else begin
            if (en0) d0 <= (d0 == 4'd9) ? 4'd0 : d0 + 4'd1;
            if (en1) d1 <= (d1 == 4'd9) ? 4'd0 : d1 + 4'd1;
            if (en2) d2 <= (d2 == 4'd9) ? 4'd0 : d2 + 4'd1;
            if (en3) d3 <= (d3 == 4'd9) ? 4'd0 : d3 + 4'd1;
            if (en4) d4 <= (d4 == 4'd9) ? 4'd0 : d4 + 4'd1;
            if (en5) d5 <= (d5 == 4'd9) ? 4'd0 : d5 + 4'd1;
            if (en6) d6 <= (d6 == 4'd9) ? 4'd0 : d6 + 4'd1;
            if (en7) d7 <= (d7 == 4'd9) ? 4'd0 : d7 + 4'd1;
        end
    end

    // ---- 选通位选择当前 BCD 位（组合 MUX，default 防 latch） ---------------
    reg [3:0] cur_digit;
    always @(*) begin
        case (scan_idx)
            3'd0: cur_digit = d0;
            3'd1: cur_digit = d1;
            3'd2: cur_digit = d2;
            3'd3: cur_digit = d3;
            3'd4: cur_digit = d4;
            3'd5: cur_digit = d5;
            3'd6: cur_digit = d6;
            default: cur_digit = d7;
        endcase
    end

    // ---- 段码查表（共阳低有效：0→C0 … 9→90，dp 恒灭） ---------------------
    function [7:0] seg_code(input [3:0] digit);
        begin
            case (digit)
                4'd0: seg_code = 8'hC0;
                4'd1: seg_code = 8'hF9;
                4'd2: seg_code = 8'hA4;
                4'd3: seg_code = 8'hB0;
                4'd4: seg_code = 8'h99;
                4'd5: seg_code = 8'h92;
                4'd6: seg_code = 8'h82;
                4'd7: seg_code = 8'hF8;
                4'd8: seg_code = 8'h80;
                4'd9: seg_code = 8'h90;
                default: seg_code = 8'hFF;
            endcase
        end
    endfunction

    // ---- 管脚输出寄存：REQ-2 复位期间全灭，释放后 1 周期内恢复 ------------
    reg [7:0] seg_code_r;
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) seg_code_r <= 8'hFF;
        else          seg_code_r <= (seg_code(cur_digit));   // 外括号：查表调用
    end

    reg [7:0] sel_r;        // 内部 one-hot 环形（释放后从 bit0 起扫）
    reg [7:0] sel_pin_r;    // 管脚输出寄存（复位期间 0）
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n)         sel_r <= 8'h01;
        else if (scan_tick) sel_r <= {sel_r[6:0], sel_r[7]};
    end
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) sel_pin_r <= 8'h00;
        else          sel_pin_r <= sel_r;
    end

    assign seg_o = seg_code_r;
    assign sel_o = sel_pin_r;
endmodule

`default_nettype wire
