//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module uart_tx #(
    parameter BITS_DATA = 8,
    parameter UART_SPEED = 9600,
    parameter BUS_SPEED = 62500000
)(
    input reset,
    input sclk,

    output txd,
    
    input [BITS_DATA-1:0] axis_data,
    input                 axis_valid,
    output                axis_ready
);


// 0             - start
// 1..BITS_DATA  - data
// BITS_DATA + 1 - stop

reg [3:0]            state;
reg [BITS_DATA:0]    data_reg;
reg [15:0]           clk_counter;
reg                  ready;

assign axis_ready = ready;

reg                  clk_div;
reg                  clk_div_prev;

assign txd = data_reg[0];

always @(posedge sclk) begin
  if (reset) begin
    clk_counter  <= 0;
    clk_div      <= 0;
    clk_div_prev <= 0;
  end else begin
    if (clk_counter >= (((2*BUS_SPEED + UART_SPEED) / UART_SPEED) / 2)) begin
     clk_counter <= 0;
     clk_div     <= ~clk_div;
    end else begin
     clk_counter <= clk_counter + 1;
    end
    
    clk_div_prev <= clk_div;
  end
end

wire div_clk_edge = (clk_div_prev != clk_div);


always @(posedge sclk) begin
  if (reset) begin
    state       <= 0;
    data_reg[0] <= 1;
    ready       <= 1;
  end else begin
    case (state)    
    0: begin
      if (axis_valid && axis_ready) begin
        data_reg[BITS_DATA:1] <= axis_data;
        state                 <= 1;
        ready                 <= 1'b0;
      end
    end
    
    default: begin
      if (div_clk_edge) begin
        if (state == 1) begin
          data_reg[0]           <= 1'b0; //Start bit
        end else begin
          data_reg[BITS_DATA:0] <= {1'b1, data_reg[BITS_DATA:1]};  // Data bits + stop bit
        end
        
        if (state == BITS_DATA + 2) begin
          state       <= 1'b0;
          ready       <= 1'b1;
        end else begin
          state       <= state + 1;
        end
      end
    end
    endcase
  end
end


endmodule
