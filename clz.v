///////////////////////////////////////////////////////////////////////////////
// COUNT LEADING ZEROS (up to 32-bit)
//
// MODULUS4 CLZ ALGO
//
// Copyright (C) 2016-2019
// Sergey.Kostanbaev@fairwaves.co
///////////////////////////////////////////////////////////////////////////////

module clz #(
  parameter B_WIDTH = 5
) (
  input [2**B_WIDTH - 1:0] data,

  output [B_WIDTH - 1:0] count,
  output                 count_nvalid
);

wire [2**(B_WIDTH - 1) - 1:0] decode_mod4;
wire [2**(B_WIDTH - 2) - 1:0] empty_mod4;

genvar i;
generate
for (i = 0; i < 2**(B_WIDTH - 2); i=i+1) begin: mod4_blk
  assign decode_mod4[2 * i + 1:2 * i] =
    data[4 * i + 3] ? 2'b00 :
    data[4 * i + 2] ? 2'b01 :
    data[4 * i + 1] ? 2'b10 : 2'b11;

  assign empty_mod4[i] = (data[4 * i + 3:4 * i] == 4'h0);
end
endgenerate

assign count_nvalid = &empty_mod4;

generate

if (B_WIDTH == 5) begin
  wire [2:0] select_mod = (~empty_mod4[7]) ? 3'h7 :
                          (~empty_mod4[6]) ? 3'h6 :
                          (~empty_mod4[5]) ? 3'h5 :
                          (~empty_mod4[4]) ? 3'h4 :
                          (~empty_mod4[3]) ? 3'h3 :
                          (~empty_mod4[2]) ? 3'h2 :
                          (~empty_mod4[1]) ? 3'h1 : 3'h0;
  wire [1:0] mod4_bits  = (select_mod == 7) ? decode_mod4[15:14] :
                          (select_mod == 6) ? decode_mod4[13:12] :
                          (select_mod == 5) ? decode_mod4[11:10] :
                          (select_mod == 4) ? decode_mod4[9:8] :
                          (select_mod == 3) ? decode_mod4[7:6] :
                          (select_mod == 2) ? decode_mod4[5:4] :
                          (select_mod == 1) ? decode_mod4[3:2] : decode_mod4[1:0];
  assign count = { ~select_mod, mod4_bits };
end else if (B_WIDTH == 4) begin
  wire [1:0] select_mod = (~empty_mod4[3]) ? 2'h3 :
                          (~empty_mod4[2]) ? 2'h2 :
                          (~empty_mod4[1]) ? 2'h1 : 2'h0;
  wire [1:0] mod4_bits  = (select_mod == 3) ? decode_mod4[7:6] :
                          (select_mod == 2) ? decode_mod4[5:4] :
                          (select_mod == 1) ? decode_mod4[3:2] : decode_mod4[1:0];
  assign count = { ~select_mod, mod4_bits };
end else if (B_WIDTH == 3) begin
  wire       select_mod = (~empty_mod4[1]);
  wire [1:0] mod4_bits  = (select_mod) ? decode_mod4[3:2] : decode_mod4[1:0];
  assign count = { ~select_mod, mod4_bits };
end else if (B_WIDTH == 2) begin
  assign count = decode_mod4;
end

endgenerate

endmodule
