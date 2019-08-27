module ul_uart_tx #(
    parameter BITS_DATA = 8,
    parameter UART_SPEED = 9600,
    parameter BUS_SPEED = 62500000,
    parameter GEN_IRQ_WHEN_HAVE = 0
)(
    input reset,
    input axis_clk,

    output txd,

    // Output data readback stream
    input [BITS_DATA-1:0]    axis_data,
    input                    axis_valid,
    output                   axis_ready,

    output [4:0]             fifo_used,
    output                   fifo_empty,

    input                    int_ready,
    output reg               int_valid
);


wire [BITS_DATA-1:0] axis_uart_data;
wire                 axis_uart_valid;
wire                 axis_uart_ready;

uart_tx  #(
    .BITS_DATA(BITS_DATA),
    .UART_SPEED(UART_SPEED),
    .BUS_SPEED(BUS_SPEED)
) uart_tx (
    .reset(reset),
    .sclk(axis_clk),

    .txd(txd),

    .axis_data(axis_uart_data),
    .axis_valid(axis_uart_valid),
    .axis_ready(axis_uart_ready)
);

// We fire interrupt only when we initally fully occupied TX buffer and then it gets
// down to low mark level
wire fifo_full        = (fifo_used == 5'b1_1111);
wire fifo_trigger_low = (fifo_used == GEN_IRQ_WHEN_HAVE);

reg fifo_full_prev;

always @(posedge axis_clk) begin
  if (reset) begin
    int_valid       <= 0;
    fifo_full_prev  <= 0; 
  end else begin
    if (~fifo_full_prev)
      fifo_full_prev  <= fifo_full;

    if (fifo_full_prev && fifo_trigger_low) begin
      int_valid      <= 1'b1;
      fifo_full_prev <= 1'b0;
    end else if (int_valid && int_ready) begin
      int_valid      <= 1'b0;
    end
  end
end

axis_fifo32 #(
  .WIDTH(BITS_DATA)
) axis_fifo32 (
  .clk(axis_clk),
  .axisrst(reset),

  .axis_rx_tdata(axis_data),
  .axis_rx_tvalid(axis_valid),
  .axis_rx_tready(axis_ready),

  .axis_tx_tdata(axis_uart_data),
  .axis_tx_tvalid(axis_uart_valid),
  .axis_tx_tready(axis_uart_ready),

  .fifo_used(fifo_used),
  .fifo_empty(fifo_empty)
);

endmodule
