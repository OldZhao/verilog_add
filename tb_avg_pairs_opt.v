//======================================================================
//  tb_avg_pairs_opt.v  ---  avg_pairs_opt 的自检 testbench
//  连续发送两帧数据, 检查 400 个输出 (每帧 200 个)
//======================================================================
`timescale 1ns/1ps

module tb_avg_pairs_opt;

    reg         clk;
    reg         rst_n;
    reg         in_valid;
    reg  [9:0]  in_data;

    wire        out_valid;
    wire [9:0]  out_data;

    reg [9:0] inputs   [0:399];
    reg [9:0] expected [0:199];

    integer i;
    integer sum;
    integer out_idx;
    integer errors;
    integer seed;

    //---------------- DUT ----------------
    avg_pairs_opt u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_data   (in_data),
        .out_valid (out_valid),
        .out_data  (out_data)
    );

    //---------------- 时钟 ----------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    //---------------- 输出检查 ----------------
    always @(posedge clk) begin
        if (rst_n && out_valid) begin
            if (out_data !== expected[out_idx % 200]) begin
                $display("FAIL: output #%0d (o%03d) = %0d, expected %0d",
                         out_idx, out_idx % 200, out_data,
                         expected[out_idx % 200]);
                errors = errors + 1;
            end

            case (out_idx)
                0:   $display("o000 = (i000=%0d + i100=%0d)/2 = %0d",
                              inputs[0], inputs[100], out_data);
                1:   $display("o001 = (i001=%0d + i101=%0d)/2 = %0d",
                              inputs[1], inputs[101], out_data);
                100: $display("o100 = (i200=%0d + i300=%0d)/2 = %0d",
                              inputs[200], inputs[300], out_data);
                101: $display("o101 = (i201=%0d + i301=%0d)/2 = %0d",
                              inputs[201], inputs[301], out_data);
            endcase

            out_idx = out_idx + 1;
        end
    end

    //---------------- 激励 ----------------
    initial begin
        $dumpfile("tb_avg_pairs_opt.vcd");
        $dumpvars(0, tb_avg_pairs_opt);

        // 512..1023, 保证两数之和超过 10bit, 可检验进位
        seed = 32'h1234_5678;
        for (i = 0; i < 400; i = i + 1)
            inputs[i] = 10'd512 + ($random(seed) & 10'h1FF);

        // 参考结果
        for (i = 0; i < 100; i = i + 1) begin
            sum = inputs[i] + inputs[i+100];
            expected[i] = sum >> 1;

            sum = inputs[i+200] + inputs[i+300];
            expected[i+100] = sum >> 1;
        end

        out_idx  = 0;
        errors   = 0;
        rst_n    = 1'b0;
        in_valid = 1'b0;
        in_data  = 10'd0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        // 连续发送两帧, 每帧 400 个数, 中间不停顿
        for (i = 0; i < 800; i = i + 1) begin
            @(negedge clk);
            in_valid = 1'b1;
            in_data  = inputs[i % 400];
        end

        @(negedge clk);
        in_valid = 1'b0;

        // 等待两帧共 400 个输出
        wait (out_idx == 400);
        repeat (2) @(posedge clk);

        if (errors == 0)
            $display("===== PASS: 400/400 outputs correct (2 frames back-to-back) =====");
        else
            $display("===== FAIL: %0d error(s) =====", errors);

        $finish;
    end

    //---------------- 超时保护 ----------------
    initial begin
        #100000;
        $display("TIMEOUT: out_idx = %0d", out_idx);
        $finish;
    end

endmodule
