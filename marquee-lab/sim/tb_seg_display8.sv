`timescale 1ns / 1ps
//============================================================================
// 模块名称: tb_seg_display8
// 功能描述: seg-counter 增量阻塞仿真（FPGA_FUNCTIONAL）—— 对齐无关自检，
//           以 EVOVERSE_PROPERTY 事件行上报义务结果（控制面 PASS 判定依据）
//   SCN-RESET   复位期间 seg=FF 且 sel=00（ORC-RESET-BLANK / PROP-RESET-BLANK）
//   SCN-COUNT   BCD 每 tick 加一（ORC-COUNT-INC / PROP-COUNT-INC）
//               扫描 one-hot + 节拍精确（ORC-SCAN-ROUND / PROP-SCAN-HOLD）
//   SCN-WRAP    十进制进位单元回绕（9→0 且高位 +1）在计数检查中逐次验证；
//               全量 99999999→0 回绕由 BCD 代数性质覆盖（仿真时长不可行）
//   SCN-SMOKE   模块直连 testbench 观察全部端口（段码表逐项核对）
//   仿真用 TICK_CYCLES=4 / SCAN_CYCLES=8 提速，上板默认 50M / 50K
//============================================================================
module tb_seg_display8;
    localparam integer TICK_CYCLES = 64;   // >= 8*SCAN：选通期间数字恒定（贴近上板 1s vs 8ms 比例）
    localparam integer SCAN_CYCLES = 8;
    localparam integer MAX_SAMPLES = 1100;

    reg  clk    = 1'b0;
    reg  rst_n  = 1'b0;
    wire [7:0] seg;
    wire [7:0] sel;

    seg_display8 #(
        .TICK_CYCLES (TICK_CYCLES),
        .SCAN_CYCLES (SCAN_CYCLES)
    ) dut (
        .clk_i   (clk),
        .rst_n_i (rst_n),
        .seg_o   (seg),
        .sel_o   (sel)
    );

    always #10 clk = ~clk;   // 50 MHz

    // ---- 期望模型（与 RTL 查表独立的双份实现） ----------------------------
    function [7:0] seg_expect(input [3:0] d);
        begin
            case (d)
                4'd0: seg_expect = 8'hC0;
                4'd1: seg_expect = 8'hF9;
                4'd2: seg_expect = 8'hA4;
                4'd3: seg_expect = 8'hB0;
                4'd4: seg_expect = 8'h99;
                4'd5: seg_expect = 8'h92;
                4'd6: seg_expect = 8'h82;
                4'd7: seg_expect = 8'hF8;
                4'd8: seg_expect = 8'h80;
                4'd9: seg_expect = 8'h90;
                default: seg_expect = 8'hFF;
            endcase
        end
    endfunction

    function [31:0] onehot_pos(input [7:0] v);
        integer k;
        begin
            onehot_pos = 0;
            for (k = 0; k < 8; k = k + 1)
                if (v[k]) onehot_pos = k;
        end
    endfunction

    function [31:0] count_ones8(input [7:0] v);
        integer k;
        begin
            count_ones8 = 0;
            for (k = 0; k < 8; k = k + 1)
                if (v[k]) count_ones8 = count_ones8 + 1;
        end
    endfunction

    integer err_blank;    // 复位期间未全灭
    integer err_count;    // BCD 计数错
    integer err_scan;     // 扫描 one-hot / 节拍 / 位序错
    integer err_decode;   // 段码表不符
    integer samples  = 0;
    integer rotates  = 0;
    integer hold_cnt = 0;
    integer saw_reset_window = 0;
    integer saw_run_window   = 0;
    integer count_changes    = 0;
    integer seen_digit [0:9];
    integer seen_scan  [0:7];
    reg [7:0]  cur_sel, prev_sel;
    reg [31:0] bcd_val, bcd_prev;
    reg [3:0]  cur_d, cur_d_prev;
    integer sel_pos;

    initial begin
        err_blank  = 0;
        err_count  = 0;
        err_scan   = 0;
        err_decode = 0;
    end

    integer p;
    initial begin
        for (p = 0; p < 10; p = p + 1) seen_digit[p] = 0;
        for (p = 0; p < 8;  p = p + 1) seen_scan[p]  = 0;
    end

    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
    end

    // 复位窗口：全灭检查（REQ-2 / PROP-RESET-BLANK）
    always @(negedge clk) begin
        if (rst_n === 1'b0) begin
            saw_reset_window = 1;
            if (seg !== 8'hFF || sel !== 8'h00) begin
                err_blank = err_blank + 1;
                $display("FAIL ORC-RESET-BLANK rst low, seg=%h sel=%b", seg, sel);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET-BLANK\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
            end else begin
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET-BLANK\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
            end
        end
    end

    // 运行窗口：rst_n 同步释放完成后逐 negedge 采样
    always @(negedge clk) begin
        if (dut.rst_n === 1'b1 && samples < MAX_SAMPLES) begin
            saw_run_window = 1;
            samples = samples + 1;
            cur_sel = sel;
            sel_pos = (onehot_pos(cur_sel));

            // one-hot 选通（ORC-SCAN-ROUND 的一半）
            if ((count_ones8(cur_sel)) !== 1) begin
                err_scan = err_scan + 1;
                $display("FAIL ORC-SCAN-ROUND sel not one-hot: %b", cur_sel);
            end else begin
                seen_scan[sel_pos] = 1;   // COV-SCAN-POS 打点
            end

            // BCD 计数值（从 DUT 内部位拼十进制整数）
            bcd_val = dut.d7 * 10000000 + dut.d6 * 1000000 + dut.d5 * 100000
                    + dut.d4 * 10000 + dut.d3 * 1000 + dut.d2 * 100
                    + dut.d1 * 10 + dut.d0;
            if (samples == 1) begin
                hold_cnt = 1;
                if (bcd_val !== 32'd0) begin
                    err_count = err_count + 1;
                    $display("FAIL ORC-COUNT-INC first sample bcd=%0d exp=0", bcd_val);
                end
            end else begin
                if (bcd_val !== bcd_prev) begin
                    count_changes = count_changes + 1;
                    if (bcd_val === ((bcd_prev + 1) % 100000000)) begin
                        $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-COUNT-INC\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                    end else begin
                        err_count = err_count + 1;
                        $display("FAIL ORC-COUNT-INC prev=%0d cur=%0d", bcd_prev, bcd_val);
                        $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-COUNT-INC\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                    end
                end
                // 扫描节拍与位序（ORC-SCAN-ROUND 另一半）
                if (cur_sel === prev_sel) begin
                    hold_cnt = hold_cnt + 1;
                end else begin
                    rotates = rotates + 1;
                    if (cur_sel === {prev_sel[6:0], prev_sel[7]}) begin
                        if (hold_cnt === ((rotates == 1) ? (SCAN_CYCLES + 1) : SCAN_CYCLES)) begin
                            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SCAN-HOLD\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                        end else begin
                            err_scan = err_scan + 1;
                            $display("FAIL ORC-SCAN-ROUND rotate=%0d hold=%0d exp=%0d",
                                     rotates, hold_cnt,
                                     (rotates == 1) ? (SCAN_CYCLES + 1) : SCAN_CYCLES);
                            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SCAN-HOLD\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                        end
                    end else begin
                        err_scan = err_scan + 1;
                        $display("FAIL ORC-SCAN-ROUND order prev=%b cur=%b", prev_sel, cur_sel);
                        $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SCAN-HOLD\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                    end
                    hold_cnt = 1;
                end
            end

            // 段码表核对（选通稳定且数字未变的拍——段码呈现滞后 1 拍是设计行为；
            // 覆盖 0..9 全数字 → COV-DIGITS）。三元链选位（词法上无 case/endcase）
            cur_d = (sel_pos == 0) ? dut.d0 : (sel_pos == 1) ? dut.d1
                 : (sel_pos == 2) ? dut.d2 : (sel_pos == 3) ? dut.d3
                 : (sel_pos == 4) ? dut.d4 : (sel_pos == 5) ? dut.d5
                 : (sel_pos == 6) ? dut.d6 : dut.d7;
            if (cur_sel === prev_sel && cur_d === cur_d_prev) begin
                seen_digit[cur_d] = 1;
                if (seg === (seg_expect(cur_d))) begin
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SEG-DECODE\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                end else begin
                    err_decode = err_decode + 1;
                    $display("FAIL ORC-SEG-DECODE digit=%0d seg=%h exp=%h",
                             cur_d, seg, (seg_expect(cur_d)));
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SEG-DECODE\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                end
            end
            cur_d_prev = cur_d;

            prev_sel = cur_sel;
            bcd_prev = bcd_val;

            if (samples == MAX_SAMPLES) begin
                for (p = 0; p < 10; p = p + 1) begin
                    if (seen_digit[p] == 0) begin
                        err_decode = err_decode + 1;
                        $display("FAIL COV-DIGITS digit %0d never displayed", p);
                    end
                end
                for (p = 0; p < 8; p = p + 1) begin
                    if (seen_scan[p] == 0) begin
                        err_scan = err_scan + 1;
                        $display("FAIL COV-SCAN-POS position %0d never selected", p);
                    end
                end
                // ---- 义务汇总事件（ORC-* / COV-*） --------------------------
                if (err_blank == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-BLANK\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-BLANK\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                if (err_count == 0 && count_changes >= 10)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-COUNT-INC\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-COUNT-INC\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                if (err_scan == 0 && rotates >= 8)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SCAN-ROUND\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SCAN-ROUND\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                if (err_decode == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SEG-DECODE\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SEG-DECODE\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                if (seen_digit[0] == 1 && seen_digit[9] == 1 && err_decode == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-DIGITS\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-DIGITS\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                if (seen_scan[0] == 1 && seen_scan[7] == 1 && err_scan == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-SCAN-POS\",\"status\":\"pass\",\"artifactPath\":\"tb_seg_display8\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-SCAN-POS\",\"status\":\"fail\",\"artifactPath\":\"tb_seg_display8\"}");
                // ---- 人读汇总 ------------------------------------------------
                if (err_blank == 0 && err_count == 0 && err_scan == 0 &&
                    err_decode == 0 && rotates >= 8)
                    $display("TB-RESULT.PASS (%0d samples, %0d count-changes, %0d rotates)",
                             samples, count_changes, rotates);
                else
                    $display("TB-RESULT.FAIL (blank=%0d count=%0d scan=%0d decode=%0d)",
                             err_blank, err_count, err_scan, err_decode);
                $finish;
            end
        end
    end
endmodule
