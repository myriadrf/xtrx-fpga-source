module bsswap #(
    parameter BYTES = 4
)(
    input  [BYTES*8 - 1:0] in,
    output [BYTES*8 - 1:0] out
);

genvar i;
genvar j;
generate
for (i = 0; i < BYTES; i=i+1) begin: byteb
  for (j = 0; j < 8; j=j+1) begin: bitc
    assign out[8*(BYTES - i - 1) + j] = in[8*i + j];
  end
end
endgenerate

// AXI   7   6   5   4   3   2   1   0
// PCIe  1.0 1.1 1.2 1.3 0.0 0.1 0.2 0.3

endmodule
