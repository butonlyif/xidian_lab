`timescale 1ns / 1ps
//============================================================================
// 模块名称: tb_input_ctrl
// 功能描述: btn-switch 增量阻塞仿真（FPGA_FUNCTIONAL）—— 对齐无关自检，
//           以 EVOVERSE_PROPERTY 事件行上报义务结果（控制面 PASS 判定依据）
//   SCN-RESET  复位期间两输出全零（ORC-RESET-ZERO / PROP-RESET-ZERO）
//   SCN-PRESS  3 路按键稳定按压各产生恰 1 个单周期脉冲（ORC-PULSE-ONE）；
//              10 位拨码翻转后第 2 拍跟随（ORC-SW-SYNC / PROP-SW-SYNC）
//   SCN-GLITCH 三类毛刺（3 拍 / DEB/10 拍 / DEB-1 拍）全部拒判，
//              随后恰 DEB 拍按压触发脉冲（阈值边界精确）
//   仿真用 DEBOUNCE_CYCLES=20 提速，上板默认 1_000_000（20 ms）
//============================================================================
module tb_input_ctrl;
    localparam integer NUM_BTNS = 3;
    localparam integer NUM_SW   = 10;
    localparam integer DEB      = 20;

    reg  clk = 1'b0;
    reg  rst_n = 1'b0;
    reg  [NUM_BTNS-1:0] btn = {NUM_BTNS{1'b1}};   // 低有效：释放态全 1
    reg  [NUM_SW-1:0]   sw  = {NUM_SW{1'b0}};
    wire [NUM_BTNS-1:0] pulse;
    wire [NUM_SW-1:0]   sw_sync;

    input_ctrl #(
        .NUM_BTNS        (NUM_BTNS),
        .NUM_SW          (NUM_SW),
        .DEBOUNCE_CYCLES (DEB)
    ) dut (
        .clk_i       (clk),
        .rst_n_i     (rst_n),
        .btn_i       (btn),
        .sw_i        (sw),
        .btn_pulse_o (pulse),
        .sw_sync_o   (sw_sync)
    );

    always #10 clk = ~clk;   // 50 MHz

    integer err_reset;     // 复位期间输出非零
    integer err_pulse;     // 脉冲数量 / 宽度错
    integer err_glitch;    // 毛刺触发脉冲
    integer err_sw;        // 拨码跟随错
    integer pulses_seen  = 0;
    integer pulses_width_err = 0;
    integer saw_reset_window = 0;
    integer sw_events = 0;
    integer press_idx = 0;
    reg [NUM_BTNS-1:0] pulse_prev;

    initial begin
        err_reset = 0;
        err_pulse = 0;
        err_glitch = 0;
        err_sw = 0;
        pulse_prev = {NUM_BTNS{1'b0}};
    end

    // 复位窗口：全零检查（REQ-4 / PROP-RESET-ZERO）
    always @(negedge clk) begin
        if (rst_n === 1'b0) begin
            saw_reset_window = 1;
            if (pulse !== {NUM_BTNS{1'b0}} || sw_sync !== {NUM_SW{1'b0}}) begin
                err_reset = err_reset + 1;
                $display("FAIL ORC-RESET-ZERO rst low, pulse=%b sw=%b", pulse, sw_sync);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET-ZERO\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
            end else begin
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-RESET-ZERO\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
            end
        end
    end

    // 脉冲宽度监测：任何连续两拍为 1 即宽度违规
    always @(negedge clk) begin
        if (rst_n === 1'b1) begin
            if (pulse !== {NUM_BTNS{1'b0}}) begin
                pulses_seen = pulses_seen + 1;
                if (pulse_prev !== {NUM_BTNS{1'b0}}) begin
                    pulses_width_err = pulses_width_err + 1;
                    $display("FAIL ORC-PULSE-ONE pulse wider than 1 cycle: %b", pulse);
                end
            end
            pulse_prev = pulse;
        end
    end

    // ---- 激励序列 ----------------------------------------------------------
    task press(input integer which, input integer cycles);
        begin
            btn[which] = 1'b0;
            repeat (cycles) @(negedge clk);
            btn[which] = 1'b1;
            repeat (DEB + 4) @(negedge clk);
        end
    endtask

    task glitch(input integer which, input integer cycles);
        begin
            btn[which] = 1'b0;
            repeat (cycles) @(negedge clk);
            btn[which] = 1'b1;
            repeat (DEB + 4) @(negedge clk);
        end
    endtask

    task sw_toggle(input integer which);
        begin
            sw[which] = ~sw[which];
            @(negedge clk);   // +1 拍：sync1 已采
            @(negedge clk);   // +2 拍：sync2 应已跟随
            if (sw_sync[which] === sw[which]) begin
                sw_events = sw_events + 1;
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SW-SYNC\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
            end else begin
                err_sw = err_sw + 1;
                $display("FAIL ORC-SW-SYNC bit %0d sw=%b sync=%b", which, sw[which], sw_sync[which]);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-SW-SYNC\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
            end
            repeat (4) @(negedge clk);
        end
    endtask

    integer k;
    integer pulses_before;
    initial begin
        rst_n = 1'b0;
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(negedge clk);

        // SCN-PRESS：3 路按键各一次稳定按压（DEB+5 拍 > 阈值）→ 各 1 脉冲
        for (k = 0; k < NUM_BTNS; k = k + 1) begin
            pulses_before = pulses_seen;
            press(k, DEB + 5);
            press_idx = k;
            if (pulses_seen === (pulses_before + 1)) begin
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-PULSE-ONE\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
            end else begin
                err_pulse = err_pulse + 1;
                $display("FAIL ORC-PULSE-ONE btn%0d pulses=%0d exp=%0d",
                         k, (pulses_seen - pulses_before), 1);
                $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-PULSE-ONE\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
            end
        end

        // SCN-GLITCH：三类毛刺（短 3 拍 / 中 DEB/10=2 拍 / 边界 DEB-1=19 拍）
        pulses_before = pulses_seen;
        glitch(0, 3);
        if (pulses_seen == pulses_before) begin
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        end else begin
            err_glitch = err_glitch + 1;
            $display("FAIL ORC-GLITCH-SUPPRESS short glitch fired");
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        end

        pulses_before = pulses_seen;
        glitch(1, 2);
        if (pulses_seen == pulses_before) begin
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        end else begin
            err_glitch = err_glitch + 1;
            $display("FAIL ORC-GLITCH-SUPPRESS mid glitch fired");
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        end

        pulses_before = pulses_seen;
        glitch(2, DEB - 1);
        if (pulses_seen == pulses_before) begin
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        end else begin
            err_glitch = err_glitch + 1;
            $display("FAIL ORC-GLITCH-SUPPRESS boundary glitch fired");
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-GLITCH-SUPPRESS\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        end

        // 阈值精确性：恰 DEB 拍的按压必须触发 1 个脉冲
        pulses_before = pulses_seen;
        press(2, DEB);
        if (pulses_seen === (pulses_before + 1)) begin
            // 阈值边界行为正确（归属 ORC-PULSE-ONE 证据链）
        end else begin
            err_pulse = err_pulse + 1;
            $display("FAIL ORC-PULSE-ONE exact-DEB press pulses=%0d exp=1",
                     (pulses_seen - pulses_before));
        end

        // SCN-PRESS 拨码：10 位逐一翻转（第 2 拍跟随检查在 task 内）
        for (k = 0; k < NUM_SW; k = k + 1) sw_toggle(k);

        // ---- 义务汇总事件（ORC-* / COV-*） ---------------------------------
        if (err_reset == 0)
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-ZERO\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        else
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-RESET-ZERO\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        if (err_pulse == 0 && pulses_width_err == 0 && pulses_seen >= 4)
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-PULSE-ONE\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        else
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-PULSE-ONE\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        if (err_glitch == 0)
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-GLITCH-SUPPRESS\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        else
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-GLITCH-SUPPRESS\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        if (err_sw == 0 && sw_events >= NUM_SW)
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SW-SYNC\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        else
            $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-SW-SYNC\",\"status\":\"fail\",\"artifactPath\":\"tb_input_ctrl\"}");
        // COV-BTNS：三路按键各产生过脉冲（press 循环已逐一验证）
        $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-BTNS\",\"status\":\"%s\",\"artifactPath\":\"tb_input_ctrl\"}",
                 (err_pulse == 0) ? "pass" : "fail");
        // COV-GLITCH-CLASS：三档毛刺全部注入过
        $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-GLITCH-CLASS\",\"status\":\"pass\",\"artifactPath\":\"tb_input_ctrl\"}");
        // COV-SW-ALL：10 位拨码全部翻转并被跟随
        $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-SW-ALL\",\"status\":\"%s\",\"artifactPath\":\"tb_input_ctrl\"}",
                 (sw_events >= NUM_SW) ? "pass" : "fail");

        // ---- 人读汇总 -------------------------------------------------------
        if (err_reset == 0 && err_pulse == 0 && err_glitch == 0 &&
            err_sw == 0 && pulses_width_err == 0)
            $display("TB-RESULT.PASS (pulses=%0d sw_events=%0d)", pulses_seen, sw_events);
        else
            $display("TB-RESULT.FAIL (reset=%0d pulse=%0d glitch=%0d sw=%0d width=%0d)",
                     err_reset, err_pulse, err_glitch, err_sw, pulses_width_err);
        $finish;
    end
endmodule
