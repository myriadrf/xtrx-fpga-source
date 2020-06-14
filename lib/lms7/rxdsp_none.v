module rxdsp_none(
   input                       clk,
   input                       reset,

   input                       dspcmd_valid,
   input [27:0]                dspcmd_data,

   input [1:0]                 dspcmd_legacy,

   input [11:0]                in_ai,
   input [11:0]                in_aq,
   input [11:0]                in_bi,
   input [11:0]                in_bq,
   input                       in_valid,
   input                       in_last,

   output [15:0]               out_ai,
   output [15:0]               out_aq,
   output [15:0]               out_bi,
   output [15:0]               out_bq,
   output                      out_valid,
   output                      out_last
);

assign out_ai = { {4{in_ai[11]}}, in_ai};
assign out_aq = { {4{in_aq[11]}}, in_aq};
assign out_bi = { {4{in_bi[11]}}, in_bi};
assign out_bq = { {4{in_bq[11]}}, in_bq};
assign out_valid = in_valid;
assign out_last = in_last;

endmodule
