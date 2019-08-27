//
// Sergey Kostanbaev 2016
//
// UL GPIO 32bit
//
//        WRITE
// 0: OUT DATA (not sampled)
//

module ul_go_base #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 1,
    parameter ADDR_TOTAL = ( 1 << (ADDR_WIDTH))
)(
    // UL Write channel
    input [ADDR_WIDTH - 1:0]  s_ul_waddr,
    input [DATA_WIDTH - 1:0]  s_ul_wdata,
    input                     s_ul_wvalid,
    output                    s_ul_wready,

    // GPO
    output [DATA_WIDTH - 1:0]  gp_out,
    output [ADDR_TOTAL - 1:0]  gp_out_strobe,
    input  [ADDR_TOTAL - 1:0]  gp_in_ready
);

genvar i;
generate
  for (i = 0; i < ADDR_TOTAL; i = i + 1) begin: strobe_gen
    assign gp_out_strobe[i] = (s_ul_wvalid && (s_ul_waddr == i));
  end
endgenerate

assign s_ul_wready = gp_in_ready[s_ul_waddr];
assign gp_out = s_ul_wdata;

endmodule
