//======================================================================
//  tb_avg_pairs.v  ---  avg_pairs 的自检 testbench
//  送入 400 个输入, 检查 200 个输出是否与参考模型一致
//======================================================================
`timescale 1ns/1ps

module tb_avg_pairs;

    reg         clk;
    reg         rst_n;
    reg         in_valid;
    reg  [9:0]  in_data;

    wire        in_ready;
    wire        out_valid;
    wire [9:0]  out_data;

    reg [9:0] inputs   [0:399];   // 输入激励
    reg [9:0] expected [0:199];   // 参考结果

    integer i;
    integer sum;
    integer out_idx;
    integer errors;
    integer seed;

    //---------------- DUT ----------------
    avg_pairs u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_data   (in_data),
        .in_ready  (in_ready),
        .out_valid (out_valid),
        .out_data  (out_data)
    );

    //---------------- 时钟 ----------------
    initial clk = 1'b0;
    always #5 clk = ~clk;         // 100 MHz

    //---------------- 输出检查 ----------------
    always @(posedge clk) begin
        if (rst_n && out_valid) begin
            if (out_data !== expected[out_idx]) begin
                $display("FAIL: o%03d = %0d, expected %0d",
                         out_idx, out_data, expected[out_idx]);
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
        $dumpfile("tb_avg_pairs.vcd");
        $dumpvars(0, tb_avg_pairs);

        // 输入取 512..1023, 任意两数之和都超过 10bit (检验进位);
        // 随机数据同时产生奇数和与偶数和 (检验 /2 的向下取整)
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

        // 依次送入 i000..i399 (遵守 in_ready)
        i = 0;
        while (i < 400) begin
            @(negedge clk);
            if (in_ready) begin
                in_valid = 1'b1;
                in_data  = inputs[i];
                i = i + 1;
            end else begin
                in_valid = 1'b0;
            end
        end

        @(negedge clk);
        in_valid = 1'b0;

        // 等待 200 个输出
        wait (out_idx == 200);
        repeat (2) @(posedge clk);

        if (errors == 0)
            $display("===== PASS: 200/200 outputs correct =====");
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
