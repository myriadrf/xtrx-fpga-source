//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module xtrx_gpio_ctrl  #(
    parameter GPIO_WIDTH = 12,
    parameter GPIO_DEF_FUNCTIONS = 0
)(
    input clk,
    input rst,

    // GPIO configuration regusters
    output                   gpio_func_ready,
    input                    gpio_func_valid,
    input [GPIO_WIDTH*2-1:0] gpio_func_data,

    output                   gpio_dir_ready,
    input                    gpio_dir_valid,
    input [GPIO_WIDTH-1:0]   gpio_dir_data,

    output                   gpio_out_ready,
    input                    gpio_out_valid,
    input [GPIO_WIDTH-1:0]   gpio_out_data,

    output                   gpio_cs_ready,
    input                    gpio_cs_valid,
    input [2*GPIO_WIDTH-1:0] gpio_cs_data,

    // User Interrupt control
    input                    gpio_in_ready,
    output                   gpio_in_valid,
    output [GPIO_WIDTH-1:0]  gpio_in_data,


    output [GPIO_WIDTH-1:0] se_gpio_oe,
    output [GPIO_WIDTH-1:0] se_gpio_out,
    input  [GPIO_WIDTH-1:0] se_gpio_in,

    // Alt function for specific GPIO(s)
    input   [GPIO_WIDTH-1:0] alt0_se_gpio_oe,
    input   [GPIO_WIDTH-1:0] alt0_se_gpio_out,
    output  [GPIO_WIDTH-1:0] alt0_se_gpio_in,

    input   [GPIO_WIDTH-1:0] alt1_se_gpio_oe,
    input   [GPIO_WIDTH-1:0] alt1_se_gpio_out,
    output  [GPIO_WIDTH-1:0] alt1_se_gpio_in,

    input   [GPIO_WIDTH-1:0] alt2_se_gpio_oe,
    input   [GPIO_WIDTH-1:0] alt2_se_gpio_out,
    output  [GPIO_WIDTH-1:0] alt2_se_gpio_in

);

localparam ALT_FUNCTION_WIDTH = 2;

// Func:
// 0     - general IO
// 1,2,3 - ALT function 0,1,2,3

reg [GPIO_WIDTH-1:0] gpio_out;
reg [GPIO_WIDTH-1:0] gpio_oe = 0;

reg [GPIO_WIDTH*ALT_FUNCTION_WIDTH-1:0] gpio_alt_sel = GPIO_DEF_FUNCTIONS;

genvar i, j;
generate
  for (i = 0; i < GPIO_WIDTH; i=i+1) begin: gpio
    wire [ALT_FUNCTION_WIDTH-1:0] altsel;
    for (j = 0; j < ALT_FUNCTION_WIDTH; j=j+1) begin
      assign altsel[j] = gpio_alt_sel[ALT_FUNCTION_WIDTH*i+j];
    end
    assign se_gpio_out[i] = (altsel == 1) ? alt0_se_gpio_out[i] :
                            (altsel == 2) ? alt1_se_gpio_out[i] :
                            (altsel == 3) ? alt2_se_gpio_out[i] : gpio_out[i];
    assign se_gpio_oe[i] = (altsel == 1) ? alt0_se_gpio_oe[i] :
                           (altsel == 2) ? alt1_se_gpio_oe[i] :
                           (altsel == 3) ? alt2_se_gpio_oe[i] : gpio_oe[i];

    assign alt0_se_gpio_in[i] = se_gpio_in[i];
    assign alt1_se_gpio_in[i] = se_gpio_in[i];
    assign alt2_se_gpio_in[i] = se_gpio_in[i];
  end
endgenerate

reg [GPIO_WIDTH-1:0] gpio_in;

assign gpio_func_ready = 1'b1;
assign gpio_dir_ready = 1'b1;
assign gpio_out_ready = 1'b1;
assign gpio_cs_ready = 1'b1;

assign gpio_in_valid = 1'b1;
assign gpio_in_data = gpio_in;

always @(posedge clk) begin
  if (rst) begin
    gpio_alt_sel <= GPIO_DEF_FUNCTIONS;
    gpio_oe      <= 0;
  end else begin
    if (gpio_func_ready && gpio_func_valid) begin
      gpio_alt_sel <= gpio_func_data;
    end
    if (gpio_dir_ready && gpio_dir_valid) begin
      gpio_oe  <= gpio_dir_data;
    end
    if (gpio_out_ready && gpio_out_valid) begin
      gpio_out <= gpio_out_data;
    end
    if (gpio_cs_ready && gpio_cs_valid) begin
      gpio_out <= (gpio_out & ~gpio_cs_data[2*GPIO_WIDTH-1:GPIO_WIDTH]) | gpio_cs_data[GPIO_WIDTH-1:0];
    end
    // Update only on requests ?!
    gpio_in <= se_gpio_in;
  end
end

endmodule


