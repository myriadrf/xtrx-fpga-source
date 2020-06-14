module ul_uart_smartcard #(
    parameter BUS_SPEED     = 62500000,
    parameter SIM_SPEED     =  4000000,
    parameter UART_DIV      =      372,
    parameter UART_DIV_BITS =        8,
    parameter BITS_SAMPLE   =        3,
    parameter GEN_IRQ_WHEN_HAVE =    0
)(
    input reset,
    input axis_clk,

    input  rxd,
    output txd_oen,
    
    output      sim_clk,
    output reg  sim_reset,
    output reg  sim_stopn,
    output reg  sim_mode33v,
    
    // Output data readback stream
    output [31:0]             axis_rdata,
    output                    axis_rvalid,
    input                     axis_rready,
    
    // Input data for UART
    input [31:0]              axis_data,
    input                     axis_valid,
    output                    axis_ready,

    // Input data for CFG & control
    input [2:0]               axis_cfg_data,
    input                     axis_cfg_valid,
    output                    axis_cfg_ready,
    
    output [31:0]             axis_stat_data,
    output                    axis_stat_valid,
    input                     axis_stat_ready,

    // Interrupt 
    input                     int_tx_ready,
    output reg                int_tx_valid,

    input                     int_rx_ready,
    output reg                int_rx_valid
);

assign axis_stat_valid  = 1'b1;
assign axis_cfg_ready   = 1'b1;
assign axis_rvalid      = 1'b1;

`include "xtrxll_regs.vh"

always @(posedge axis_clk) begin
  if (reset) begin
    sim_reset   <= 0;
    sim_stopn   <= 0;
    sim_mode33v <= 0;
  end else begin
    if (axis_cfg_valid && axis_cfg_ready) begin
      sim_reset   <= axis_cfg_data[WR_SIM_CTRL_RESET];
      sim_stopn   <= axis_cfg_data[WR_SIM_CTRL_ENABLE];
      sim_mode33v <= axis_cfg_data[WR_SIM_CTRL_33V];
    end
  end
end

`ifdef PRECISE_DIV
// Smartcard clock div
localparam CLK_DIV = ((2*BUS_SPEED + SIM_SPEED) / SIM_SPEED) / 2;

reg       sim_clk_reset;
reg       sim_clk_reg;
reg [7:0] sim_clk_div_reg;

always @(posedge axis_clk) begin
  if (reset) begin
    sim_clk_div_reg <= 0;
    sim_clk_reg     <= 0;
    sim_clk_reset   <= 1;
  end else begin
    if (sim_clk_div_reg == (CLK_DIV/2) - 1) begin
      sim_clk_div_reg <= 0;
      sim_clk_reg     <= ~sim_clk_reg;
      
      if (sim_clk_reg)
        sim_clk_reset   <= 0;
    end else begin
      sim_clk_div_reg <= sim_clk_div_reg + 1;
    end
  end
end

assign sim_clk = sim_clk_reg;

`else
localparam CLK_DIV = 16;

reg [3:0] sim_clk_div_reg;

always @(posedge axis_clk) begin
  if (reset) begin
    sim_clk_div_reg <= 0;
  end else begin
    sim_clk_div_reg <= sim_clk_div_reg + 1;
  end
end

assign sim_clk = sim_clk_div_reg[3];

`endif


wire  [7:0] tx_data;
wire        tx_valid;
wire        tx_ready;
    
wire [7:0]  rx_data;
wire        rx_valid;
wire        rx_ready;
    
wire        parity_error;

wire        full_sim_reset = ~sim_reset || reset;

uart_smartcard #(
    .CLK_DIV(UART_DIV * CLK_DIV),
    .CLK_DIV_BITS(UART_DIV_BITS + 6),
    .BITS_SAMPLE(BITS_SAMPLE)
) uart_smartcard (
    .reset(full_sim_reset),
//    .baseclk(sim_clk),
    .baseclk(axis_clk),

    .rxd(rxd),
    .txd_oen(txd_oen),
    
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready),
    
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    
    .parity_error(parity_error)
);

wire [4:0] rx_fifo_used;
wire       rx_fifo_empty;

wire [4:0] tx_fifo_used;
wire       tx_fifo_empty;

assign axis_rdata[31:UART_FIFOTX_EMPTY+1] = 0;
assign axis_rdata[UART_FIFOTX_EMPTY]                                                 = tx_fifo_empty;
assign axis_rdata[UART_FIFOTX_USED_OFF+UART_FIFOTX_USED_BITS-1:UART_FIFOTX_USED_OFF] = tx_fifo_used;

assign axis_rdata[UART_FIFORX_EMPTY]  = rx_fifo_empty;
assign axis_rdata[UART_FIFORX_PARERR] = parity_error;
assign axis_rdata[13:8]  = 0;


assign axis_stat_data = axis_rdata;


axis_fifo32 #(
  .WIDTH(8)
) rx_axis_fifo32 (
  .clk(axis_clk),
  .axisrst(full_sim_reset),

  .axis_rx_tdata(rx_data),
  .axis_rx_tvalid(rx_valid),
  .axis_rx_tready(rx_ready),

  .axis_tx_tdata(axis_rdata[7:0]),
  .axis_tx_tvalid(),
  .axis_tx_tready(axis_rready),

  .fifo_used(rx_fifo_used),
  .fifo_empty(rx_fifo_empty)
);

axis_fifo32 #(
  .WIDTH(8)
) tx_axis_fifo32 (
  .clk(axis_clk),
  .axisrst(full_sim_reset),

  .axis_rx_tdata(axis_data[7:0]),
  .axis_rx_tvalid(axis_valid),
  .axis_rx_tready(axis_ready),

  .axis_tx_tdata(tx_data),
  .axis_tx_tvalid(tx_valid),
  .axis_tx_tready(tx_ready),

  .fifo_used(tx_fifo_used),
  .fifo_empty(tx_fifo_empty)
);


reg rx_fifo_empty_prev;
always @(posedge axis_clk) begin
  if (reset) begin
    int_rx_valid       <= 0;
    rx_fifo_empty_prev <= 1'b1; 
  end else begin
    rx_fifo_empty_prev <= rx_fifo_empty;

    if (rx_fifo_empty_prev == 1'b1 && rx_fifo_empty == 1'b0) begin
      int_rx_valid <= 1'b1;
    end else if (int_rx_valid && int_rx_ready) begin
      int_rx_valid <= 1'b0;
    end
  end
end

// We fire interrupt only when we initally fully occupied TX buffer and then it gets
// down to low mark level
wire tx_fifo_full        = (tx_fifo_used == 5'b1_1111);
wire tx_fifo_trigger_low = (tx_fifo_used == GEN_IRQ_WHEN_HAVE);

reg tx_fifo_full_prev;

always @(posedge axis_clk) begin
  if (reset) begin
    int_tx_valid       <= 0;
    tx_fifo_full_prev  <= 0; 
  end else begin
    if (~tx_fifo_full_prev)
      tx_fifo_full_prev  <= tx_fifo_full;

    if (tx_fifo_full_prev && tx_fifo_trigger_low) begin
      int_tx_valid      <= 1'b1;
      tx_fifo_full_prev <= 1'b0;
    end else if (int_tx_valid && int_tx_ready) begin
      int_tx_valid      <= 1'b0;
    end
  end
end

endmodule

