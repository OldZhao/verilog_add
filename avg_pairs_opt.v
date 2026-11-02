`timescale 1ns/1ps

//======================================================================
//  avg_pairs_opt.v  ---  avg_pairs 的优化版
//
//  优化点:
//    1. 只使用 1 个 100 x 10bit 缓冲, 存储器减少到原来的 1/4
//    2. 输入/输出同时进行, 每 400 个输入周期完成一帧
//       (原设计需要 400 输入 + 200 输出 = 600 周期)
//    3. 支持连续帧, 不需要 in_ready 反压 (输入间隔也可以)
//
//  时间线 (n 为 in_valid 有效的输入序号, c = 0..99):
//    n =   0.. 99 : buf[c] <= i[n]                     // 存 i000..i099
//    n = 100..199 : buf[c] <= (buf[c] + i[n]) / 2      // 存入 o000..o099
//    n = 200..299 : out <= buf[c]; buf[c] <= i[n]      // 输出 o, 存 i200..i299
//    n = 300..399 : out <= (buf[c] + i[n]) / 2         // 输出 o100..o199
//
//  原设计用 4 个 bank 是为了在一个周期内同时读两个数; 本设计把
//  "两个数相差 100 个周期" 这一特点利用起来, 用时间换存储空间,
//  每周期只需要一次读/写, 一个 bank 就够.
//======================================================================

module avg_pairs_opt (
    input  wire        clk,
    input  wire        rst_n,      // 异步复位, 低有效
    input  wire        in_valid,   // 输入有效
    input  wire [9:0]  in_data,    // i000..i399
    output reg         out_valid,  // 输出有效
    output reg  [9:0]  out_data    // o000..o199
);

    // 唯一的 100 x 10bit 缓冲
    reg [9:0] sample_buf [0:99];

    reg [1:0] phase;               // 0..3, 对应上面四个时间段
    reg [6:0] col;                 // 0..99

    // 11bit 求和, 防止进位丢失
    wire [10:0] sum     = {1'b0, sample_buf[col]} + {1'b0, in_data};
    wire [9:0]  avg_val = sum[10:1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase     <= 2'd0;
            col       <= 7'd0;
            out_valid <= 1'b0;
            out_data  <= 10'd0;
        end else begin
            // 默认无效, 只有 phase 2/3 且 in_valid 时产生输出
            out_valid <= 1'b0;

            if (in_valid) begin
                case (phase)
                //------------ 存 i000..i099 ------------
                2'd0: begin
                    sample_buf[col] <= in_data;
                end

                //------------ 算出 o000..o099 并暂存 ------------
                2'd1: begin
                    sample_buf[col] <= avg_val;
                end

                //------------ 输出 o, 同时存 i200..i299 ------------
                // 同一地址先读后写: 读出的旧值是 o[c], 写入的是 i[200+c]
                2'd2: begin
                    out_data  <= sample_buf[col];
                    out_valid <= 1'b1;
                    sample_buf[col]  <= in_data;
                end

                //------------ 输出 o100..o199 ------------
                default: begin
                    out_data  <= avg_val;
                    out_valid <= 1'b1;
                end
                endcase

                if (col == 7'd99) begin
                    col   <= 7'd0;
                    phase <= phase + 2'd1;    // 4 个阶段循环, 支持连续帧
                end else begin
                    col <= col + 7'd1;
                end
            end
        end
    end

endmodule
