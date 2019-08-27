module axis_async_fifo32 #(
  parameter WIDTH = 12,
  parameter DEEP_BITS = 5,
  parameter GRAY_BITS = DEEP_BITS,
  parameter PIPELINED = 0
) (
  input clkrx,
  input rstrx,

  input [WIDTH-1:0]  axis_rx_tdata,
  input              axis_rx_tvalid,
  output             axis_rx_tready,

  input clktx,
  input rsttx,

  output [WIDTH-1:0] axis_tx_tdata,
  output             axis_tx_tvalid,
  input              axis_tx_tready
);

localparam CC_GRAY_BITS = ((GRAY_BITS > DEEP_BITS) ? DEEP_BITS : GRAY_BITS) + 1;

wire               rx_addr_inc;
wire [DEEP_BITS:0] rx_addr;
wire [DEEP_BITS:0] rx_addr_cc_tx; // tx addr latched @ rx domain

wire               tx_addr_inc;
wire [DEEP_BITS:0] tx_addr;
wire [DEEP_BITS:0] tx_addr_cc_rx; // rx addr latched @ tx domain


cross_counter #(
    .WIDTH(DEEP_BITS + 1),
    .GRAY_BITS(CC_GRAY_BITS),
    .OUT_PIPELINED(PIPELINED)
) rx_addr_cross (
    .inrst(rstrx),
    .inclk(clkrx),
    .incmdvalid(rx_addr_inc),
    .incmdinc(1'b1),
    .incnt(rx_addr),

    .outrst(rsttx),
    .outclk(clktx),
    .outcnt(rx_addr_cc_tx)
);

cross_counter #(
    .WIDTH(DEEP_BITS + 1),
    .GRAY_BITS(CC_GRAY_BITS),
    .OUT_PIPELINED(PIPELINED)
) tx_addr_cross (
    .inrst(rsttx),
    .inclk(clktx),
    .incmdvalid(tx_addr_inc),
    .incmdinc(1'b1),
    .incnt(tx_addr),

    .outrst(rstrx),
    .outclk(clkrx),
    .outcnt(tx_addr_cc_rx)
);

wire [DEEP_BITS:0] rx_diff = rx_addr - tx_addr_cc_rx;
wire [DEEP_BITS:0] tx_diff = rx_addr_cc_tx - tx_addr - 1'b1;


wire       rx_full  = rx_diff[DEEP_BITS];
wire       tx_empty = tx_diff[DEEP_BITS];

//TODO: add pipeline option for full & empty

assign    axis_rx_tready = ~rx_full;
assign    rx_addr_inc = axis_rx_tvalid && axis_rx_tready;

assign    axis_tx_tvalid = ~tx_empty;
assign    tx_addr_inc = axis_tx_tready && axis_tx_tvalid;

generate
if (DEEP_BITS <= 5) begin: deep32
ram32xsdp #(
    .WIDTH(WIDTH)
) ram (
    .wclk(clkrx),
    .we(rx_addr_inc),
    .waddr(rx_addr[DEEP_BITS-1:0]),
    .datai(axis_rx_tdata),

    .raddr(tx_addr[DEEP_BITS-1:0]),
    .datao(axis_tx_tdata)
);
end else if (DEEP_BITS == 6) begin: deep64
ram64xsdp #(
    .WIDTH(WIDTH)
) ram (
    .wclk(clkrx),
    .we(rx_addr_inc),
    .waddr(rx_addr[5:0]),
    .datai(axis_rx_tdata),

    .raddr(tx_addr[5:0]),
    .datao(axis_tx_tdata)
);
end else begin
// TODO

end
endgenerate

endmodule

