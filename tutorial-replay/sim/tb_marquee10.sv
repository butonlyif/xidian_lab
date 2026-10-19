`timescale 1ns / 1ps
//============================================================================
// 模块名称: tb_marquee10
// 功能描述: marquee-lab 基线阻塞仿真（FPGA_FUNCTIONAL）—— 对齐无关自检，
//           经顶层 t20f256_xd_ps_eval_stage0 集成路径观察（integration-smoke），
//           以 EVOVERSE_PROPERTY 事件行上报义务结果（控制面 PASS 判定依据）
//   SCN-RESET    arst_n==0 采样点 led 全零（ORC-RESET-ZERO / PROP-RESET）
//   SCN-MAINFLOW 释放后 one-hot 循环左移（ORC-ONEHOT / ORC-SEQUENCE）
//   SCN-BOUNDARY 相邻步进间隔恰 STEP_CYCLES；bit9→bit0 回绕（ORC-STEP-PERIOD）
//   COV-STATES   点亮位置 0..9 各出现至少一次；COV-RESET 两类窗口各出现一次
//   仿真用 STEP_CYCLES=4 提速，上板默认 6_250_000（8 Hz）
//============================================================================
module tb_marquee10;
    localparam integer NUM_LEDS    = 10;
    localparam integer STEP_CYCLES = 4;
    localparam integer CHECKS      = 40 * STEP_CYCLES;   // ≈4 圈完整旋转

    reg  clk    = 1'b0;
    reg  arst_n = 1'b0;

    wire led_user,  led_user2, led_user3, led_user4,  led_user5;
    wire led_user6, led_user7, led_user8, led_user9,  led_user10;

    // 管脚位序拼回总线：bit0=led_user … bit9=led_user10
    wire [NUM_LEDS-1:0] led = {led_user10, led_user9, led_user8, led_user7,
                               led_user6,  led_user5, led_user4, led_user3,
                               led_user2,  led_user};

    t20f256_xd_ps_eval_stage0 #(
        .STEP_CYCLES (STEP_CYCLES)
    ) dut (
        .clk_50m   (clk),
        .arst_n    (arst_n),
        .led_user  (led_user),
        .led_user2 (led_user2),
        .led_user3 (led_user3),
        .led_user4 (led_user4),
        .led_user5 (led_user5),
        .led_user6 (led_user6),
        .led_user7 (led_user7),
        .led_user8 (led_user8),
        .led_user9 (led_user9),
        .led_user10(led_user10)
    );

    // 50 MHz 时钟（20 ns 周期）
    always #10 clk = ~clk;

    function [31:0] count_ones(input [NUM_LEDS-1:0] v);
        integer k;
        begin
            count_ones = 0;
            for (k = 0; k < NUM_LEDS; k = k + 1)
                if (v[k]) count_ones = count_ones + 1;
        end
    endfunction

    function [31:0] pos_of(input [NUM_LEDS-1:0] v);
        integer k;
        begin
            pos_of = 0;
            for (k = 0; k < NUM_LEDS; k = k + 1)
                if (v[k]) pos_of = k;
        end
    endfunction

    integer err_rst0;    // 复位期间非全零
    integer err_first;   // 释放后首采样非 bit0
    integer err_onehot;  // 非 one-hot 采样
    integer err_rotate;  // 旋转序列错
    integer err_hold;    // 步进间隔错
    integer checks   = 0;
    integer rotates  = 0;
    integer hold_cnt = 0;
    integer saw_reset_window = 0;
    integer saw_run_window   = 0;
    integer seen_pos [0:NUM_LEDS-1];
    reg [NUM_LEDS-1:0] cur;
    reg [NUM_LEDS-1:0] prev;

    initial begin
        err_rst0   = 0;
        err_first  = 0;
        err_onehot = 0;
        err_rotate = 0;
        err_hold   = 0;
    end

    integer p;
    initial begin
        for (p = 0; p < NUM_LEDS; p = p + 1) seen_pos[p] = 0;
    end

    initial begin
        arst_n = 1'b0;
        repeat (5) @(posedge clk);
        arst_n = 1'b1;    // 异步释放；DUT 内部 3 级同步释放
    end

    // 复位窗口检查：arst_n==0 的每个 negedge 采样点输出全零（REQ-2 / PROP-RESET）
    always @(negedge clk) begin
        if (arst_n === 1'b0) begin
            saw_reset_window = 1;
            if (led !== {NUM_LEDS{1'b0}}) begin
                err_rst0 = err_rst0 + 1;
                $display("FAIL ORC-RESET-ZERO arst_n low, led=%b exp=0", led);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
            end else begin
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
            end
        end
    end

    // 运行窗口：rst_n 同步释放完成后的每个 negedge 采样（无固定相位假设）
    always @(negedge clk) begin
        if (dut.u_marquee.rst_n === 1'b1 && checks < CHECKS) begin
            saw_run_window = 1;
            checks = checks + 1;
            cur    = led;
            seen_pos[(pos_of(cur))] = 1;    // COV-STATES 位置打点
            if (count_ones(cur) === 1) begin
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-ONEHOT\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
            end else begin
                err_onehot = err_onehot + 1;
                $display("FAIL PROP-ONEHOT sample=%0d led=%b", checks, cur);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-ONEHOT\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
            end
            if (checks == 1) begin
                hold_cnt = 1;
                // 释放后首个采样 = bit0（初始 one-hot 码型）
                if (cur !== {{(NUM_LEDS-1){1'b0}}, 1'b1}) begin
                    err_first = err_first + 1;
                    $display("FAIL ORC-RESET-ZERO sample=1 led=%b exp=0000000001", cur);
                end
            end else if (cur === prev) begin
                hold_cnt = hold_cnt + 1;
            end else begin
                rotates = rotates + 1;
                // 循环左移一位（含 bit9→bit0 回绕）
                if (cur === {prev[NUM_LEDS-2:0], prev[NUM_LEDS-1]}) begin
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-ROTATE\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                end else begin
                    err_rotate = err_rotate + 1;
                    $display("FAIL PROP-ROTATE rotate=%0d prev=%b cur=%b",
                             rotates, prev, cur);
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-ROTATE\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                end
                // 相邻步进间隔恰 STEP_CYCLES（ORC-STEP-PERIOD）。
                // 首次旋转合法地多 1 拍：复位释放后需先计满首个 STEP_CYCLES，
                // 且 led_out_r 输出寄存引入固定 1 拍呈现延迟。
                if (hold_cnt === ((rotates == 1) ? (STEP_CYCLES + 1) : STEP_CYCLES)) begin
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-HOLD\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                end else begin
                    err_hold = err_hold + 1;
                    $display("FAIL PROP-HOLD rotate=%0d hold=%0d exp=%0d",
                             rotates, hold_cnt,
                             (rotates == 1) ? (STEP_CYCLES + 1) : STEP_CYCLES);
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-HOLD\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                end
                hold_cnt = 1;
            end
            prev = cur;

            if (checks == CHECKS) begin
                // COV-STATES：位置 0..9 全部出现
                for (p = 0; p < NUM_LEDS; p = p + 1) begin
                    if (seen_pos[p] == 0) begin
                        err_onehot = err_onehot + 1;
                        $display("FAIL COV-STATES position %0d never lit", p);
                    end
                end
                // COV-RESET：两类窗口各出现一次
                if (saw_reset_window == 0 || saw_run_window == 0) begin
                    err_rst0 = err_rst0 + 1;
                    $display("FAIL COV-RESET reset=%0d run=%0d",
                             saw_reset_window, saw_run_window);
                end
                // ---- 义务汇总事件（ORC-* / COV-*） --------------------------
                if (err_rst0 == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-ZERO\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-ZERO\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                if (err_onehot == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-ONEHOT\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-ONEHOT\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                if (err_rotate == 0 && rotates >= NUM_LEDS)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SEQUENCE\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SEQUENCE\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                if (err_hold == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-STEP-PERIOD\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-STEP-PERIOD\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                if (seen_pos[0] == 1 && seen_pos[NUM_LEDS-1] == 1 && err_onehot == 0)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-STATES\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-STATES\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                if (saw_reset_window == 1 && saw_run_window == 1)
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-RESET\",\"status\":\"pass\",\"artifactPath\":\"tb_marquee10\"}");
                else
                    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-RESET\",\"status\":\"fail\",\"artifactPath\":\"tb_marquee10\"}");
                // ---- 人读汇总 ------------------------------------------------
                if (err_rst0 == 0 && err_first == 0 && err_onehot == 0 &&
                    err_rotate == 0 && err_hold == 0 && rotates >= NUM_LEDS)
                    $display("TB-RESULT.PASS (%0d samples, %0d rotations)",
                             checks, rotates);
                else
                    $display("TB-RESULT.FAIL (rst0=%0d first=%0d onehot=%0d rotate=%0d hold=%0d)",
                             err_rst0, err_first, err_onehot, err_rotate, err_hold);
                $finish;
            end
        end
    end
endmodule
