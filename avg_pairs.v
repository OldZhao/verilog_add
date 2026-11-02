`timescale 1ns/1ps

//======================================================================
//  avg_pairs.v
//  400 个 10bit 输入 -> 200 个 10bit 输出 (两两求平均)
//
//  输入 i000..i399, 每个时钟送入一个 (in_valid=1)
//  输出 o000..o199, 每个时钟输出一个 (out_valid=1)
//
//  对应关系 (c = 0..99):
//      o[c]     = (i[c]     + i[c+100]) / 2     // o000..o099
//      o[100+c] = (i[200+c] + i[300+c]) / 2     // o100..o199
//
//  举例:
//      o000 = (i000 + i100) / 2
//      o001 = (i001 + i101) / 2
//      o100 = (i200 + i300) / 2
//      o101 = (i201 + i301) / 2
//
//  说明:
//    * /2 用右移 1 位实现, 结果为向下取整 (floor)
//    * 收齐 400 个输入后, 连续 200 个时钟输出结果, 然后可接收下一帧
//======================================================================

module avg_pairs (
    input  wire        clk,
    input  wire        rst_n,      // 异步复位, 低电平有效
    input  wire        in_valid,   // 输入有效
    input  wire [9:0]  in_data,    // 输入数据 i000..i399
    output wire        in_ready,   // 1: 可以接收输入
    output reg         out_valid,  // 输出有效
    output reg  [9:0]  out_data    // 输出数据 o000..o199
);

    //------------------------------------------------------------------
    // 存储: 4 个 bank, 每个 100 x 10bit
    //   bank0: i000..i099    bank1: i100..i199
    //   bank2: i200..i299    bank3: i300..i399
    //------------------------------------------------------------------
    reg [9:0] bank0 [0:99];
    reg [9:0] bank1 [0:99];
    reg [9:0] bank2 [0:99];
    reg [9:0] bank3 [0:99];

    localparam S_LOAD = 1'b0;     // 接收 400 个输入
    localparam S_OUT  = 1'b1;     // 输出 200 个结果

    reg        state;
    reg [1:0]  wr_bank;           // 当前写入的 bank
    reg [6:0]  wr_col;            // 当前写入的列 0..99
    reg [8:0]  in_cnt;            // 已接收输入个数 0..399
    reg [7:0]  out_cnt;           // 已输出结果个数 0..199

    assign in_ready = (state == S_LOAD);

    //------------------------------------------------------------------
    // 输出侧读地址
    //   out_cnt = 0..99    -> bank0/bank1 同一列
    //   out_cnt = 100..199 -> bank2/bank3 同一列
    //------------------------------------------------------------------
    wire       second = (out_cnt >= 8'd100);
    wire [7:0] rd_idx = second ? (out_cnt - 8'd100) : out_cnt;
    wire [6:0] rd_col = rd_idx[6:0];

    wire [9:0] a = second ? bank2[rd_col] : bank0[rd_col];
    wire [9:0] b = second ? bank3[rd_col] : bank1[rd_col];

    // 用 11bit 相加, 防止 10bit 加法丢进位; 右移一位完成 /2
    wire [10:0] sum     = {1'b0, a} + {1'b0, b};
    wire [9:0]  avg_val = sum[10:1];

    //------------------------------------------------------------------
    // 主状态机
    //------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_LOAD;
            wr_bank   <= 2'd0;
            wr_col    <= 7'd0;
            in_cnt    <= 9'd0;
            out_cnt   <= 8'd0;
            out_valid <= 1'b0;
            out_data  <= 10'd0;
        end else begin
            case (state)

            //---------------- 接收 400 个输入 ----------------
            S_LOAD: begin
                out_valid <= 1'b0;

                if (in_valid) begin
                    case (wr_bank)
                        2'd0:    bank0[wr_col] <= in_data;
                        2'd1:    bank1[wr_col] <= in_data;
                        2'd2:    bank2[wr_col] <= in_data;
                        default: bank3[wr_col] <= in_data;
                    endcase

                    in_cnt <= in_cnt + 9'd1;

                    if (wr_col == 7'd99) begin
                        wr_col  <= 7'd0;
                        wr_bank <= wr_bank + 2'd1;
                    end else begin
                        wr_col <= wr_col + 7'd1;
                    end

                    if (in_cnt == 9'd399) begin   // 第 400 个输入写入完成
                        state   <= S_OUT;
                        out_cnt <= 8'd0;
                        in_cnt  <= 9'd0;
                    end
                end
            end

            //---------------- 连续输出 200 个结果 ----------------
            S_OUT: begin
                out_valid <= 1'b1;
                out_data  <= avg_val;

                if (out_cnt == 8'd199) begin
                    out_cnt <= 8'd0;
                    state   <= S_LOAD;        // 可以接收下一帧
                end else begin
                    out_cnt <= out_cnt + 8'd1;
                end
            end

            endcase
        end
    end

endmodule
