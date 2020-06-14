//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

`timescale 1ns / 1ps

module xlnx_pci_clocking #(
    parameter PCIE_LANE          = 2,                       // PCIe number of lanes
    parameter PCIE_LINK_SPEED    = 2,                       // PCIe link speed
    parameter PCIE_USERCLK_FREQ  = 3,                       // PCIe user clock 1 frequency
    parameter PCIE_OOBCLK_MODE   = 1,                       // PCIe oob clock mode
    parameter PCIE_GEN1_MODE     = 0
) (
    //---------- Input -------------------------------------
    input                       CLK_RST_N,
    input                       CLK_TXOUTCLK,
    input       [PCIE_LANE-1:0] CLK_PCLK_SEL,

    //---------- Output ------------------------------------
    output                      CLK_PCLK,
    output                      CLK_DCLK,
    output                      CLK_USERCLK,
    output                      CLK_MMCM_LOCK,

    input                       alt_refclk,
    input                       alt_refclk_use,

    output                      clk_50mhz_out,

    // MMCM DRP configuration port
    input         cfg_mmcm_drp_dclk,
    input [15:0]  cfg_mmcm_drp_di,
    input [6:0]   cfg_mmcm_drp_daddr,
    input         cfg_mmcm_drp_den,
    input         cfg_mmcm_drp_dwe,
    output [15:0] cfg_mmcm_drp_do,
    output        cfg_mmcm_drp_drdy,
    input  [3:0]  cfg_mmcm_drp_gpio_out,
    output [3:0]  cfg_mmcm_drp_gpio_in
);

localparam          DIVCLK_DIVIDE    =  1;
localparam          CLKFBOUT_MULT_F  =  10;
localparam          CLKIN1_PERIOD    =  10;
localparam          CLKOUT0_DIVIDE_F = 8;
localparam          CLKOUT1_DIVIDE   = 4;
localparam          CLKOUT2_DIVIDE   = (PCIE_USERCLK_FREQ == 5) ?  2 :
                                       (PCIE_USERCLK_FREQ == 4) ?  4 :
                                       (PCIE_USERCLK_FREQ == 3) ?  8 :
                                       (PCIE_USERCLK_FREQ == 1) ? 32 : 16;
localparam          CLKOUT3_DIVIDE   = CLKOUT2_DIVIDE;
localparam          CLKOUT4_DIVIDE   = 62;

wire                        refclk;
wire                        mmcm_fb;
wire                        clk_125mhz;
wire                        clk_125mhz_buf;
wire                        clk_250mhz;
wire                        userclk1;
reg                         pclk_sel = 1'd0;

wire                        pclk_1;
wire                        pclk;
wire                        userclk1_1;
wire                        mmcm_lock;
wire                        clk_50mhz;

(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)    reg [PCIE_LANE-1:0] pclk_sel_reg1 = {PCIE_LANE{1'd0}};
(* ASYNC_REG = "TRUE", SHIFT_EXTRACT = "NO" *)    reg [PCIE_LANE-1:0] pclk_sel_reg2 = {PCIE_LANE{1'd0}};

always @ (posedge pclk)
begin
  if (!CLK_RST_N) begin
    pclk_sel_reg1 <= {PCIE_LANE{1'd0}};
    pclk_sel_reg2 <= {PCIE_LANE{1'd0}};
  end else begin
    pclk_sel_reg1 <= CLK_PCLK_SEL;
    pclk_sel_reg2 <= pclk_sel_reg1;
  end
end

BUFG txoutclk_i(.I(CLK_TXOUTCLK), .O(refclk));

wire refclk2;
BUFG refclk2_i(.I(alt_refclk), .O(refclk2));

MMCME2_ADV #(
    .BANDWIDTH                  ("OPTIMIZED"),
    .CLKOUT4_CASCADE            ("FALSE"),
    .COMPENSATION               ("ZHOLD"),
    .STARTUP_WAIT               ("FALSE"),
    .DIVCLK_DIVIDE              (DIVCLK_DIVIDE),
    .CLKFBOUT_MULT_F            (CLKFBOUT_MULT_F),
    .CLKFBOUT_PHASE             (0.000),
    .CLKFBOUT_USE_FINE_PS       ("FALSE"),
    .CLKOUT0_DIVIDE_F           (CLKOUT0_DIVIDE_F),
    .CLKOUT0_PHASE              (0.000),
    .CLKOUT0_DUTY_CYCLE         (0.500),
    .CLKOUT0_USE_FINE_PS        ("FALSE"),
    .CLKOUT1_DIVIDE             (CLKOUT1_DIVIDE),
    .CLKOUT1_PHASE              (0.000),
    .CLKOUT1_DUTY_CYCLE         (0.500),
    .CLKOUT1_USE_FINE_PS        ("FALSE"),
    .CLKOUT2_DIVIDE             (CLKOUT2_DIVIDE),
    .CLKOUT2_PHASE              (0.000),
    .CLKOUT2_DUTY_CYCLE         (0.500),
    .CLKOUT2_USE_FINE_PS        ("FALSE"),
    .CLKOUT3_DIVIDE             (CLKOUT3_DIVIDE),
    .CLKOUT3_PHASE              (0.000),
    .CLKOUT3_DUTY_CYCLE         (0.500),
    .CLKOUT3_USE_FINE_PS        ("FALSE"),
    .CLKOUT4_DIVIDE             (CLKOUT4_DIVIDE),
    .CLKOUT4_PHASE              (0.000),
    .CLKOUT4_DUTY_CYCLE         (0.500),
    .CLKOUT4_USE_FINE_PS        ("FALSE"),
    .CLKIN1_PERIOD              (CLKIN1_PERIOD),
    .CLKIN2_PERIOD              (CLKIN1_PERIOD),
    .REF_JITTER1                (0.010)
) mmcm_i (
     //---------- Input ------------------------------------
    .CLKIN1                     (refclk),
    .CLKIN2                     (refclk2),
    .CLKINSEL                   (~alt_refclk_use),
    .CLKFBIN                    (mmcm_fb),
    .RST                        (!CLK_RST_N),
    .PWRDWN                     (1'd0),

    //---------- Output ------------------------------------
    .CLKFBOUT                   (mmcm_fb),
    .CLKFBOUTB                  (),
    .CLKOUT0                    (clk_125mhz),
    .CLKOUT0B                   (),
    .CLKOUT1                    (clk_250mhz),
    .CLKOUT1B                   (),
    .CLKOUT2                    (userclk1),
    .CLKOUT2B                   (),
    .CLKOUT3                    (),
    .CLKOUT3B                   (),
    .CLKOUT4                    (clk_50mhz),
    .CLKOUT5                    (),
    .CLKOUT6                    (),
    .LOCKED                     (mmcm_lock),

    //---------- Dynamic Reconfiguration -------------------
    .DCLK                       (cfg_mmcm_drp_dclk),
    .DADDR                      (cfg_mmcm_drp_daddr),
    .DEN                        (cfg_mmcm_drp_den),
    .DWE                        (cfg_mmcm_drp_dwe),
    .DI                         (cfg_mmcm_drp_di),
    .DO                         (cfg_mmcm_drp_do),
    .DRDY                       (cfg_mmcm_drp_drdy),

    //---------- Dynamic Phase Shift -----------------------
    .PSCLK                      (1'd0),
    .PSEN                       (1'd0),
    .PSINCDEC                   (1'd0),
    .PSDONE                     (),

    //---------- Status ------------------------------------
    .CLKINSTOPPED               (cfg_mmcm_drp_gpio_in[1]),
    .CLKFBSTOPPED               (cfg_mmcm_drp_gpio_in[2])
);

assign cfg_mmcm_drp_gpio_in[0] = mmcm_lock;
assign cfg_mmcm_drp_gpio_in[3] = 0;

//---------- Select PCLK MUX ---------------------------------------------------
generate
if (PCIE_LINK_SPEED != 1) begin : pclk_i1_bufgctrl
  BUFGCTRL pclk_i1(
        .CE0                        (1'd1),
        .CE1                        (1'd1),
        .I0                         (clk_125mhz),
        .I1                         (clk_250mhz),
        .IGNORE0                    (1'd0),
        .IGNORE1                    (1'd0),
        .S0                         (~pclk_sel),
        .S1                         ( pclk_sel),
        .O                          (pclk_1)
    );
end else begin : pclk_i1_bufg
  BUFG pclk_i1(.I(clk_125mhz), .O(clk_125mhz_buf));
  assign pclk_1 = clk_125mhz_buf;
end
endgenerate

generate
if (PCIE_LINK_SPEED != 1) begin : dclk_i_bufg
  BUFG dclk_i(.I(clk_125mhz), .O(CLK_DCLK));
end else begin : dclk_i
  assign CLK_DCLK = clk_125mhz_buf;
end
endgenerate


generate
if (PCIE_GEN1_MODE == 1'b1 && PCIE_USERCLK_FREQ == 3) begin :userclk1_i1_no_bufg
    assign userclk1_1 = pclk_1;
end else begin : userclk1_i1
    BUFG usrclk1_i1(.I(userclk1), .O(userclk1_1));
end
endgenerate

assign pclk         = pclk_1;
assign CLK_USERCLK  = userclk1_1;

always @(posedge pclk)
begin
  if (!CLK_RST_N) begin
    pclk_sel <= 1'd0;
  end else begin
    if (&pclk_sel_reg2)
      pclk_sel <= 1'd1; // 250Mhz
    else if (&(~pclk_sel_reg2))
      pclk_sel <= 1'd0; // 125Mhz
    else
      pclk_sel <= pclk_sel;

  end
end

BUFG clk_50mhz_i(.I(clk_50mhz), .O(clk_50mhz_out));

assign CLK_PCLK      = pclk;
assign CLK_MMCM_LOCK = mmcm_lock;

endmodule
