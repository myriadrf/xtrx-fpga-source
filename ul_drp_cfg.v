//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module ul_drp_cfg #(
  parameter PORTS = 4,
  parameter GPIO_RESET_P0 = 0,
  parameter GPIO_RESET_P1 = 0,
  parameter GPIO_RESET_P2 = 0,
  parameter GPIO_RESET_P3 = 0
)(
    input reset,
    input axis_clk,

    input [31:0] axis_in_data,
    input        axis_in_valid,
    output       axis_in_ready,

    output [31:0] axis_out_data,
    output        axis_out_valid,
    input         axis_out_ready,


    output        drp_clk,

    // DRP port0
    output [15:0] drp_di_0,
    output [6:0]  drp_daddr_0,
    output        drp_den_0,
    output        drp_dwe_0,
    input  [15:0] drp_do_0,
    input         drp_drdy_0,

    output [3:0]  drp_gpio_out_0,
    input  [3:0]  drp_gpio_in_0,

    // DRP port1
    output [15:0] drp_di_1,
    output [6:0]  drp_daddr_1,
    output        drp_den_1,
    output        drp_dwe_1,
    input  [15:0] drp_do_1,
    input         drp_drdy_1,

    output [3:0]  drp_gpio_out_1,
    input  [3:0]  drp_gpio_in_1,

    // DRP port2
    output [15:0] drp_di_2,
    output [6:0]  drp_daddr_2,
    output        drp_den_2,
    output        drp_dwe_2,
    input  [15:0] drp_do_2,
    input         drp_drdy_2,

    output [3:0]  drp_gpio_out_2,
    input  [3:0]  drp_gpio_in_2,

    // DRP port3
    output [15:0] drp_di_3,
    output [6:0]  drp_daddr_3,
    output        drp_den_3,
    output        drp_dwe_3,
    input  [15:0] drp_do_3,
    input         drp_drdy_3,

    output [3:0]  drp_gpio_out_3,
    input  [3:0]  drp_gpio_in_3
);

`include "xtrxll_regs.vh"

reg [1:0]  drp_selector;

reg [15:0] drp_di;
reg [6:0]  drp_daddr;
reg        drp_dwe;
reg [3:0]  drp_den;

assign drp_di_0 = drp_di;
assign drp_di_1 = drp_di;
assign drp_di_2 = drp_di;
assign drp_di_3 = drp_di;

assign drp_daddr_0 = drp_daddr;
assign drp_daddr_1 = drp_daddr;
assign drp_daddr_2 = drp_daddr;
assign drp_daddr_3 = drp_daddr;

assign drp_dwe_0 = drp_dwe;
assign drp_dwe_1 = drp_dwe;
assign drp_dwe_2 = drp_dwe;
assign drp_dwe_3 = drp_dwe;

assign drp_den_0 = drp_den[0];
assign drp_den_1 = drp_den[1];
assign drp_den_2 = drp_den[2];
assign drp_den_3 = drp_den[3];

assign drp_clk = axis_clk;

wire [15:0] drp_do = (drp_selector == 2'b00) ? drp_do_0 :
                     (drp_selector == 2'b01) ? drp_do_1 :
                     (drp_selector == 2'b10) ? drp_do_2 : drp_do_3;
wire        drp_drdy = (drp_selector == 2'b00) ? drp_drdy_0 :
                       (drp_selector == 2'b01) ? drp_drdy_1 :
                       (drp_selector == 2'b10) ? drp_drdy_2 : drp_drdy_3;



wire [15:0] di    = axis_in_data[15:0];
wire [6:0]  daddr = axis_in_data[GP_PORT_DRP_ADDR_BITS - 1 + GP_PORT_DRP_ADDR_OFF:GP_PORT_DRP_ADDR_OFF];
wire cmd_regacc   = axis_in_data[GP_PORT_DRP_REGEN];
wire cmd_regacc_wr= axis_in_data[GP_PORT_DRP_REGWR];
wire [3:0] c_gpio = axis_in_data[4 - 1 + GP_PORT_DRP_GPIO_OFF:GP_PORT_DRP_GPIO_OFF];

// 29 is reservd for future port extention
wire [1:0]  sel   = axis_in_data[31:30];


assign axis_out_valid = 1'b1;

assign axis_out_data[15:0]  = drp_do;

assign axis_out_data[19:16] = drp_gpio_in_0;
assign axis_out_data[23:20] = drp_gpio_in_1;
assign axis_out_data[27:24] = drp_gpio_in_2;
assign axis_out_data[31:28] = drp_gpio_in_3;

reg [3:0] gpio_out_0;
reg [3:0] gpio_out_1;
reg [3:0] gpio_out_2;
reg [3:0] gpio_out_3;

assign drp_gpio_out_0 = gpio_out_0;
assign drp_gpio_out_1 = gpio_out_1;
assign drp_gpio_out_2 = gpio_out_2;
assign drp_gpio_out_3 = gpio_out_3;


reg         state_rdy;
assign axis_in_ready = state_rdy; //1'b1;

always @(posedge axis_clk) begin
  if (reset) begin
    gpio_out_0 <= GPIO_RESET_P0;
    gpio_out_1 <= GPIO_RESET_P1;
    gpio_out_2 <= GPIO_RESET_P2;
    gpio_out_3 <= GPIO_RESET_P3;

    drp_den    <= 4'b0;
    drp_dwe    <= 1'b0;

    state_rdy  <= 1'b1;

    drp_di     <= 0;
    drp_daddr  <= 0;
  end else begin
    if (axis_in_valid && axis_in_ready && ~cmd_regacc) begin
      case (sel)
        2'b00: gpio_out_0 <= c_gpio;
        2'b01: gpio_out_1 <= c_gpio;
        2'b10: gpio_out_2 <= c_gpio;
        2'b11: gpio_out_3 <= c_gpio;
      endcase
      drp_selector <= sel;

      drp_den      <= 4'b0;
      //drp_dwe   <= 1'b0;
      state_rdy    <= 1'b1;
    end else begin
      if (axis_in_ready && axis_in_valid) begin
        drp_den      <= (4'b0001 << sel);
        drp_dwe      <= cmd_regacc_wr;
        drp_di       <= di;
        drp_daddr    <= daddr;
        state_rdy    <= 1'b0;
        drp_selector <= sel;
      end else begin
        if (~state_rdy && drp_drdy) begin
          state_rdy <= 1'b1;
        end

        if (|drp_den) begin
          drp_den <= 4'b0;
          //drp_dwe <= 1'b0;
        end
      end
    end
  end
end



endmodule
