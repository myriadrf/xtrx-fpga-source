module uart_rx #(
    parameter BITS_DATA = 8,
    parameter UART_SPEED = 9600,
    parameter BUS_SPEED = 62500000,
    parameter BITS_SAMPLE = 3
)(
    input reset,
    input sclk,

    input rxd,

    output [BITS_DATA-1:0] data,
    output                 data_valid,

    output                 debug_rxd_one,
    output                 debug_rxd_zero
);

(* ASYNC_REG = "TRUE" *) reg [BITS_SAMPLE - 1:0] rxd_sampled;
always @(posedge sclk) begin
  if (reset) begin
    rxd_sampled <= ((1 << BITS_SAMPLE) - 1);
  end else begin
    rxd_sampled <= { rxd_sampled[BITS_SAMPLE - 2:0], rxd };
  end
end

wire sampled_one  = (rxd_sampled == ((1 << BITS_SAMPLE) - 1));
wire sampled_zero = (rxd_sampled == 0);

assign debug_rxd_one = sampled_one;
assign debug_rxd_zero = sampled_zero;

// 0             - start
// 1..BITS_DATA  - data
// BITS_DATA + 1 - stop

reg [4:0]            state;
reg [BITS_DATA-1:0]  data_reg;
reg [15:0]           clk_counter;
reg                  finished;

assign data = data_reg;
assign data_valid = finished;
assign debug_state = state;
assign debug_clk_counter = clk_counter;

always @(posedge sclk) begin
  if (reset) begin
    state       <= 0;
    data_reg    <= 0;
    clk_counter <= 0;
    finished    <= 0;
  end else begin
    if (state == 0) begin
      clk_counter <= 0;

      // Start bit detected
      if (sampled_zero) begin
        state      <= state + 1;
        finished   <= 1'b0;
      end
    end else if (state == (2*BITS_DATA + 3)) begin
      if (sampled_one) begin
        state      <= 0;
        finished   <= 1'b1;
      end
    end else begin
      if (clk_counter >= (((2*BUS_SPEED + UART_SPEED) / UART_SPEED) / 4)) begin
        clk_counter <= 0;
        state       <= state + 1;

        if (state[0] == 1'b1) begin
          data_reg <= { sampled_one, data_reg[BITS_DATA-1:1] };
        end
      end else begin
        clk_counter <= clk_counter + 1;
      end
    end
  end
end


endmodule
