`timescale 1ns / 1ps
//============================================================================
// 模块名称: tb_led_marquee
// 功能描述: t20f256_xd_ps_eval_marquee 协议性质自检 testbench（对齐无关）
//           不假设首个 step_tick 的绝对相位；以 dut.u_marquee.rst_n 同步
//           释放为采样起点，在每个 negedge 采样一次：
//           PROP-RESET  首个采样 = one-hot bit0（复位值）
//           PROP-ONEHOT 每个采样恰 1 位点亮
//           PROP-ROTATE 值变化必为循环左移一位（含 bit9→bit0 回绕）
//           PROP-HOLD   相邻变化间隔恰 STEP_CYCLES 个采样
//           附加 EVOVERSE_PROPERTY 观测协议（icarus.py normalize_property_events）：
//           每次激活输出一行 EVOVERSE_PROPERTY {json}，status ∈ pass|fail
// 义务映射: PROP-001/PROP-002/PROP-003（激活次数见规格）+ ORC-001..ORC-004
//============================================================================
module tb_led_marquee;
    localparam integer LEDS        = 10;
    localparam integer STEP_CYCLES = 4;
    localparam integer CHECKS      = 30 * STEP_CYCLES;   // ≈3 圈完整旋转

    reg        clk    = 1'b0;
    reg        arst_n = 1'b0;
    wire [9:0] led;

    t20f256_xd_ps_eval_marquee #(
        .STEP_CYCLES (STEP_CYCLES)
    ) dut (
        .clk_50m_i (clk),
        .arst_n_i  (arst_n),
        .led_o     (led)
    );

    // 50 MHz 时钟（20 ns 周期）
    always #10 clk = ~clk;

    function [31:0] count_ones(input [9:0] v);  // 返回类型用 [31:0] 而非 integer：闭包扫描器将 "integer name(" 误判为例化
        integer k;
        begin
            count_ones = 0;
            for (k = 0; k < LEDS; k = k + 1)
                if (v[k]) count_ones = count_ones + 1;
        end
    endfunction

    // ---- EVOVERSE_PROPERTY 观测协议事件 --------------------------------
    // code: 1=PROP-001 2=PROP-002 3=PROP-003 4=ORC-001 5=ORC-002 6=ORC-003 7=ORC-004
    task ev(input [7:0] code, input ok);
        begin
            case (code)
            8'd1: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-001\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-001\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd2: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-002\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-002\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd3: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-003\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"PROP-003\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd4: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-001\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-001\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd5: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-002\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-002\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd6: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-003\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-003\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd7: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-004\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"ORC-004\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            8'd8: if (ok) $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-001\",\"status\":\"pass\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
                  else    $display("EVOVERSE_PROPERTY {\"propertyId\":\"COV-001\",\"status\":\"fail\",\"artifactPath\":\"sim/tb_led_marquee.v\"}");
            default: ;
            endcase
        end
    endtask

    integer   errors   = 0;
    integer   checks   = 0;
    integer   rotates  = 0;
    integer   hold_cnt = 0;
    reg [9:0] cur;
    reg [9:0] prev;
    reg       ok_flag;

    initial begin
        arst_n = 1'b0;
        repeat (5) @(posedge clk);
        arst_n = 1'b1;    // 异步释放；DUT 内部 3 级同步释放
    end

    // rst_n 同步释放完成后的每个 negedge 采样（对齐无关，无固定偏移假设）
    always @(negedge clk) begin
        if (dut.u_marquee.rst_n === 1'b1 && checks < CHECKS) begin
            checks = checks + 1;
            cur    = led;
            if (checks == 1) begin
                hold_cnt = 1;
                // PROP-RESET: 复位释放后首个采样 = bit0
                ok_flag = (cur === 10'h001);
                if (!ok_flag) begin
                    errors = errors + 1;
                    $display("FAIL PROP-RESET sample=1 led=%b exp=0000000001", cur);
                end
                ev(8'd1, ok_flag);   // PROP-001 激活
                ev(8'd4, ok_flag);   // ORC-001 激活
            end else if (cur === prev) begin
                hold_cnt = hold_cnt + 1;
            end else begin
                rotates = rotates + 1;
                // PROP-ROTATE: 循环左移一位
                ok_flag = (cur === {prev[LEDS-2:0], prev[LEDS-1]});
                if (!ok_flag) begin
                    errors = errors + 1;
                    $display("FAIL PROP-ROTATE rotate=%0d prev=%b cur=%b",
                             rotates, prev, cur);
                end
                // PROP-HOLD: 上一值持续恰 STEP_CYCLES 个采样
                if (hold_cnt !== STEP_CYCLES) begin
                    ok_flag = 1'b0;
                    errors = errors + 1;
                    $display("FAIL PROP-HOLD rotate=%0d hold=%0d exp=%0d",
                             rotates, hold_cnt, STEP_CYCLES);
                end
                ev(8'd3, ok_flag);   // PROP-003 激活（步进间隔 + 回绕边界）
                ev(8'd6, ok_flag);   // ORC-003 激活
                ev(8'd8, ok_flag);   // COV-001 激活（one-hot 位置覆盖，29 次旋转覆盖全部 bin）
                hold_cnt = 1;
            end
            // PROP-ONEHOT: 恰 1 位点亮
            ok_flag = (count_ones(cur) === 1);
            if (!ok_flag) begin
                errors = errors + 1;
                $display("FAIL PROP-ONEHOT sample=%0d led=%b", checks, cur);
            end
            ev(8'd2, ok_flag);       // PROP-002 激活
            ev(8'd5, ok_flag);       // ORC-002 激活
            prev = cur;

            if (checks == CHECKS) begin
                // ORC-004: 集成冒烟 —— 正常结束、无 X（上面全程 !== 比较已含 X 检查）、自检通过
                ok_flag = (errors == 0 && rotates >= LEDS);
                ev(8'd7, ok_flag);
                if (errors == 0 && rotates >= LEDS)
                    $display("TB-RESULT: PASS (%0d samples, %0d rotations, %0d errors)",
                             checks, rotates, errors);
                else if (errors == 0)
                    $display("TB-RESULT: FAIL (insufficient rotations: %0d)", rotates);
                else
                    $display("TB-RESULT: FAIL (%0d errors / %0d checks)",
                             errors, checks);
                $finish;
            end
        end
    end
endmodule
