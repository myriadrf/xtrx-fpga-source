module ul_uart_rx #(
    parameter BITS_DATA = 8,
    parameter UART_SPEED = 9600,
    parameter BUS_SPEED = 62500000,
    parameter BITS_SAMPLE = 3
)(
    input reset,
    input axis_clk,

    input rxd,

    // Output data readback stream
    output [15:0]             axis_rdata,
    output                    axis_rvalid,
    input                     axis_rready,

    // Interrupt
    input                     int_ready,
    output reg                int_valid
);

wire [BITS_DATA-1:0] data;
wire                 data_valid;

wire                 debug_rxd_one;
wire                 debug_rxd_zero;

uart_rx  #(
    .BITS_DATA(BITS_DATA),
    .UART_SPEED(UART_SPEED),
    .BUS_SPEED(BUS_SPEED),
    .BITS_SAMPLE(BITS_SAMPLE)
) uart_rx (
    .reset(reset),
    .sclk(axis_clk),

    .rxd(rxd),

    .data(data),
    .data_valid(data_valid),

    .debug_rxd_one(debug_rxd_one),
    .debug_rxd_zero(debug_rxd_zero)
);

wire [4:0]  fifo_used;
wire        fifo_empty;

assign    axis_rvalid              = 1'b1;

`include "xtrxll_regs.vh"

assign    axis_rdata[UART_FIFORX_EMPTY] = fifo_empty;
assign    axis_rdata[14:10]             = fifo_used;
assign    axis_rdata[9:8]               = {debug_rxd_one, debug_rxd_zero};
//assign    axis_rdata[10:BITS_DATA]      = 0;

reg processed;
wire axis_valid = data_valid && ~processed;
wire axis_ready;

//reg buf_overrun; // TODO

always @(posedge axis_clk) begin
  if (reset) begin
    processed <= 0;
  end else begin
    if (axis_valid && axis_ready) begin
      processed <= 1;
    end else if (processed && ~data_valid) begin
      processed <= 0;
    end
  end
end

reg fifo_empty_prev;
always @(posedge axis_clk) begin
  if (reset) begin
    int_valid       <= 0;
    fifo_empty_prev <= 1'b1;
  end else begin
    fifo_empty_prev <= fifo_empty;

    if (fifo_empty_prev == 1'b1 && fifo_empty == 1'b0) begin
      int_valid <= 1'b1;
    end else if (int_valid && int_ready) begin
      int_valid <= 1'b0;
    end
  end
end

axis_fifo32 #(
  .WIDTH(BITS_DATA)
) axis_fifo32 (
  .clk(axis_clk),
  .axisrst(reset),

  .axis_rx_tdata(data),
  .axis_rx_tvalid(axis_valid),
  .axis_rx_tready(axis_ready),

  .axis_tx_tdata(axis_rdata[BITS_DATA-1:0]),
  .axis_tx_tvalid(),
  .axis_tx_tready(axis_rready),

  .fifo_used(fifo_used),
  .fifo_empty(fifo_empty)
);


endmodule