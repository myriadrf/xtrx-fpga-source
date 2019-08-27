`timescale 1ns / 1ps

module xtrxr4_top #(
  parameter NO_GTIME = 0,
  parameter NO_PPS = 0
)(
  output  [1:0] pci_exp_txp,
  output  [1:0] pci_exp_txn,
  input   [1:0] pci_exp_rxp,
  input   [1:0] pci_exp_rxn,

  // pseudo - GPIO
  output   led_2,
  input    option,

  input    sys_clk_p,
  input    sys_clk_n,
  input    sys_rst_n,

  // LMS SPI
  output   lms_io_sdio,
  output   lms_i_sclk,
  input    lms_o_sdo,
  output   lms_i_saen,

  // LMS generic
  //////////////////////////////////
  output   lms_i_reset,
  output   lms_i_rxen,
  output   lms_i_txen,

  //////////////////////////////////
  output   lms_i_gpwrdwn,


  // LMS port1 - TX
  output        lms_i_txnrx1,
  input         lms_o_mclk1,
  output        lms_i_fclk1,
  input         lms_io_iqsel1,
  input  [11:0] lms_diq1,

  // LMS port2 - RX
  output        lms_i_txnrx2,
  input         lms_o_mclk2,
  output        lms_i_fclk2,
  inout         lms_io_iqsel2,
  inout [11:0]  lms_diq2,

  // Aux (bypass, clk control)
  //output        en_bp3v3_n,
  //output        en_bpvio_n,
  output        en_tcxo,
  output        ext_clk,

  output        en_gps,
  output        iovcc_sel,
  output        en_smsigio,

  input         fpga_clk_vctcxo,

  // GPS
  input         gps_pps,
  input         gps_txd,
  output        gps_rxd,

  // GPIO
  inout [11:0]  gpio,
  inout         gpio13,


  // I2C_BUS1 (3v3: TMP108, LTC26x6, LP8758 [FPGA])
  inout         i2c1_sda,
  inout         i2c1_scl,

  // I2C_BUS2 (vio: LP8758 [LMS])
  inout         i2c2_sda,
  inout         i2c2_scl,

  //TX/RX SWITCH
  output        tx_switch,
  output        rx_switch_1,
  output        rx_switch_2,

  // FLASH & BOOT
  inout [3:0]   flash_d,
  output        flash_fcs_b,

  //inout         boot_safe,

  // SIM
  output        sim_mode,
  output        sim_enable,
  output        sim_clk,
  output        sim_reset,
  inout         sim_data,

  // USB2 Phy
  inout [7:0]   usb_d,
  input         usb_clk,
  output        usb_nrst,
  output        usb_26m,
  input         usb_dir,
  inout         usb_stp,
  input         usb_nxt
);

//localparam NO_PPS           = 1;
//localparam NO_GTIME         = 1;

localparam XTRX_FW_ID = 16'h0400;
localparam XTRX_COMPAT_ID = 8'h01;

localparam XTRX_I2C_DEV_LP_FPGA = 8'b0_110_0000;
localparam XTRX_I2C_DEV_DAC     = 8'b0_110_0010;
localparam XTRX_I2C_DEV_TMP     = 8'b0_100_1010;
localparam XTRX_I2C_DEV_LP_LMS  = 8'b1_110_0000;

localparam XTRX_I2C_LUT = { XTRX_I2C_DEV_LP_LMS, XTRX_I2C_DEV_TMP, XTRX_I2C_DEV_DAC, XTRX_I2C_DEV_LP_FPGA };

localparam XTRX_I2C_DEV_PDAC    = 8'b0_100_1011;

localparam XTRX_I2C_LUT5 = { XTRX_I2C_DEV_LP_LMS, XTRX_I2C_DEV_TMP, XTRX_I2C_DEV_PDAC, XTRX_I2C_DEV_LP_FPGA };

// config
localparam FLASH_ASYNC_CLOCKS = 1;

wire drp_clk;
// global user clock in AXI domains
wire user_clk;

wire [15:0] xtrx_ctrl_lines;

`include "../xtrxll_regs.vh"
//wire xtrx_enbpvio_n          = xtrx_ctrl_lines[GP_PORT_XTRX_ENBPVIO_N];
//wire xtrx_enbp3v3_n          = xtrx_ctrl_lines[GP_PORT_XTRX_ENBP3V3_N];
wire xtrx_ext_clk            = xtrx_ctrl_lines[GP_PORT_XTRX_EXT_CLK];
wire xtrx_pd_tcxo            = xtrx_ctrl_lines[GP_PORT_XTRX_PD_TCXO];
wire xtrx_engps              = ~xtrx_ctrl_lines[GP_PORT_XTRX_ENGPS];
wire xtrx_iovcc_sel          = ~xtrx_ctrl_lines[GP_PORT_XTRX_VCCSEL];
wire xtrx_ensmsig            = xtrx_ctrl_lines[GP_PORT_XTRX_ENSMDIG];
wire xtrx_alut               = xtrx_ctrl_lines[GP_PORT_XTRX_ALTI2CLUT];

wire lms7_digreset           = xtrx_ctrl_lines[GP_PORT_LMS_CTRL_DIGRESET];
wire lms7_reset              = xtrx_ctrl_lines[GP_PORT_LMS_CTRL_RESET];
wire lms7_g_pwrdn            = xtrx_ctrl_lines[GP_PORT_LMS_CTRL_GPWR];
wire lms7_rxen               = xtrx_ctrl_lines[GP_PORT_LMS_CTRL_RXEN];
wire lms7_txen               = xtrx_ctrl_lines[GP_PORT_LMS_CTRL_TXEN];
wire lms7_rx_fclk_dis        = ~xtrx_ctrl_lines[GP_PORT_LMS_FCLK_RX_GEN];
wire lms7_rx_diq_termdisable = xtrx_ctrl_lines[GP_PORT_LMS_RX_TERM_DIS];


//OBUF   en_bp3v3_n_obuf (.O(en_bp3v3_n), .I(xtrx_enbp3v3_n));
//OBUF   en_bpvio_n_obuf (.O(en_bpvio_n), .I(xtrx_enbpvio_n));
OBUF   en_tcxo_obuf    (.O(en_tcxo),    .I(~xtrx_pd_tcxo));
OBUF   ext_clk_obuf    (.O(ext_clk),    .I(xtrx_ext_clk));
OBUF   en_gps_obuf     (.O(en_gps),     .I(xtrx_engps));
OBUF   iovcc_sel_obuf  (.O(iovcc_sel),  .I(xtrx_iovcc_sel));
OBUF   en_smsigio_obuf (.O(en_smsigio), .I(xtrx_ensmsig));


wire [31:0] xtrx_i2c_lut = (xtrx_alut) ? XTRX_I2C_LUT5 : XTRX_I2C_LUT;
/////////////////////////////////////////////////////////////////
// USB

wire        phy_clk;
IBUF   phy_clk_ibuf (.O(phy_clk), .I(usb_clk));

wire        phy_nrst;
wire        phy_dir;
wire        phy_nxt;
wire        phy_stp;

OBUF   phy_nrst_obuf (.O(usb_nrst), .I(phy_nrst));
IOBUF  phy_stpio_buf(
  .IO(usb_stp),
  .I(phy_stp),
  .T(~phy_nrst),
  .O()
);
IBUF   phy_dir_ibuf (.O(phy_dir), .I(usb_dir));
IBUF   phy_nxt_ibuf (.O(phy_nxt), .I(usb_nxt));

wire [7:0] phy_do;
wire [7:0] phy_di;
wire       phy_doe;

genvar j;
generate
begin
for (j = 0; j < 8; j = j + 1) begin: usb
  IOBUF phy_d_buf(
    .IO(usb_d[j]),
    .I(phy_do[j]),
    .T(~phy_doe),
    .O(phy_di[j])
  );
end
end
endgenerate

////////////////////////////////////////////////////////////////////
// GPIO
wire [13:0] xtrx_gpio_oe;
wire [13:0] xtrx_gpio_out;
wire [13:0] xtrx_gpio_in;

generate
begin
for (j = 0; j < 12; j = j + 1) begin: gpiobufs
  IOBUF gpio_buf(
    .IO(gpio[j]),
    .I(xtrx_gpio_out[j]),
    .T(~xtrx_gpio_oe[j]),
    .O(xtrx_gpio_in[j])
  );
end
end
endgenerate

OBUF   led_2_obuf  (.O(led_2),      .I(xtrx_gpio_out[12]));
IBUF   option_ibuf (.I(option),     .O(xtrx_gpio_in[12]));

IOBUF boot_safe_bf(
//    .IO(boot_safe),
    .IO(gpio13),
    .I(xtrx_gpio_out[13]),
    .T(~xtrx_gpio_oe[13]),
    .O(xtrx_gpio_in[13])
);

//////////////////////////////////////////////////////////////////////////
// Clocks & reset

wire fpga_clk_vctcxo_buf;
wire fpga_clk_vctcxo_buf_i;
IBUF   fpga_clk_vctcxo_ibuf (.O(fpga_clk_vctcxo_buf_i), .I(fpga_clk_vctcxo));

BUFR #(.BUFR_DIVIDE("BYPASS")) fpga_clk_vctcxo_bufg (
  .I(fpga_clk_vctcxo_buf_i),
  .O(fpga_clk_vctcxo_buf),
  .CE(),
  .CLR()
);

OBUF   usb_26m_buf( .O(usb_26m), .I(fpga_clk_vctcxo_buf));


wire      user_reset;
wire      user_lnk_up;
wire      sys_rst_n_c;
wire      sys_clk;


// Buffers
IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));

IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));

wire onepps;
IBUF   onepps_ibuf          (.O(onepps),              .I(gps_pps));

wire rx_running;
wire tx_running;

// LMS POWER CONTROL
OBUF   lms7_reset_obuf( .O(lms_i_reset), .I(lms7_reset));
OBUF   lms7_txen_obuf( .O(lms_i_txen), .I(lms7_txen));
OBUF   lms7_rxen_obuf( .O(lms_i_rxen), .I(lms7_rxen));
OBUF   lms7_gpwrdwn_obuf( .O(lms_i_gpwrdwn), .I(lms7_g_pwrdn));
//OBUF   lms7_digrst_obuf( .O(lms_i_digrst), .I(lms7_digrst));

// LMS SPI
wire lms7_mosi;
wire lms7_sck;
wire lms7_miso;
wire lms7_sen;

OBUF lms7_mosi_obuf(  .O(lms_io_sdio), .I(lms7_mosi));
OBUF lms7_sck_obuf(  .O(lms_i_sclk), .I(lms7_sck));
OBUF lms7_sen_obuf(  .O(lms_i_saen), .I(lms7_sen));
IBUF lms7_miso_ibuf( .O(lms7_miso), .I(lms_o_sdo));

/////////////////////////////////
// FLASH QSPI
wire [3:0] flash_dout;
wire [3:0] flash_din;
wire [3:0] flash_ndrive;
wire       flash_ncs;
wire       flash_cclk;

genvar i;
generate
for (i = 0; i < 4; i=i+1) begin: gen_d
  IOBUF flash_buf_d (
    .IO(flash_d[i]),
    .I(flash_dout[i]),
    .T(flash_ndrive[i]),
    .O(flash_din[i])
  );
end
endgenerate

OBUF flash_buf_cs ( .O(flash_fcs_b), .I(flash_ncs) );

// Internal RC clock generator
wire cfg_mclk;

wire cfg_clk;
wire clk_50mhz_out;

generate
if (FLASH_ASYNC_CLOCKS != 0) begin
assign flash_cclk = clk_50mhz_out;
end else begin
assign flash_cclk = user_clk;
end
endgenerate

(* keep = "TRUE" *)
STARTUPE2 #(
    .PROG_USR("FALSE")//,
//    .SIM_CCLK_FREQ(66.0)
) STARTUPE2_inst (
    .CFGCLK( cfg_clk ),
    .CFGMCLK( cfg_mclk ),
    .EOS(/* NC */),
    .PREQ(/* NC */),
    .CLK(1'b0),
    .GSR(1'b0),
    .GTS(1'b0),
    .KEYCLEARB(1'b0),
    .PACK(1'b0),
    .USRCCLKO( flash_cclk ),
    .USRCCLKTS(1'b0),
    .USRDONEO(1'b1),  // Set DONE to 1
    .USRDONETS(1'b0)
);

///////////////////////////////////////////////////////////////////////////////
// LMS PORT1 -- in
wire         cfg_mmcm_drp_dclk_p0;
wire [15:0]  cfg_mmcm_drp_di_p0;
wire [6:0]   cfg_mmcm_drp_daddr_p0;
wire         cfg_mmcm_drp_den_p0;
wire         cfg_mmcm_drp_dwe_p0;
wire [15:0]  cfg_mmcm_drp_do_p0;
wire         cfg_mmcm_drp_drdy_p0;
wire [3:0]   cfg_mmcm_drp_gpio_out_p0;
wire [3:0]   cfg_mmcm_drp_gpio_in_p0;

wire         cfg_rx_idelay_clk_p0;
wire [4:0]   cfg_rx_idelay_data_p0;
wire [3:0]   cfg_rx_idelay_addr_p0;

wire         cfg_port_tx_p0;
wire         cfg_port_enable_p0;
wire         cfg_port_rxfclk_dis_p0;
wire         cfg_port_rxterm_dis_p0;
wire [2:0]   hwcfg_port_p0;

wire [19:0]  stat_rx_frame_err_p0;
wire [19:0]  stat_rx_corr_p0;

wire             rx_ref_clk_p0;
wire             rx_data_clk_p0;
wire             rx_data_ready_p0;
wire             rx_data_valid_p0;
wire [11:0]      rx_data_s0_p0;
wire [11:0]      rx_data_s1_p0;
wire [11:0]      rx_data_s2_p0;
wire [11:0]      rx_data_s3_p0;

// DATA O
wire              tx_ref_clk_p0;
wire              tx_data_clk_p0;
wire              tx_data_valid_p0;
wire              tx_data_ready_p0;
wire [11:0]       tx_data_s0_p0;
wire [11:0]       tx_data_s1_p0;
wire [11:0]       tx_data_s2_p0;
wire [11:0]       tx_data_s3_p0;


localparam LML_PHY_RX_MODE = 1;
localparam LML_PHY_TX_MODE = 1;

localparam RX_LML2 = 0; // 1;

xlnx_lms7_lml_phy #(
  .IN_MODE((RX_LML2) ? 0 : LML_PHY_RX_MODE),   // 0 - off, 1 - slow, 2 - fast
  .OUT_MODE((RX_LML2) ? LML_PHY_TX_MODE : 0),  // 0 - off, 1 - slow, 2 - fast
  .IN_FIFO(1)
) lml_tx (
// LMS7 LML port
  .lms_i_txnrx(lms_i_txnrx1),
  .lms_io_iqsel(lms_io_iqsel1),
  .lms_o_mclk(lms_o_mclk1),
  .lms_i_fclk(lms_i_fclk1),
  .lms_io_diq(lms_diq1),

// PHY configuration port
  .cfg_mmcm_drp_dclk(cfg_mmcm_drp_dclk_p0),
  .cfg_mmcm_drp_di(cfg_mmcm_drp_di_p0),
  .cfg_mmcm_drp_daddr(cfg_mmcm_drp_daddr_p0),
  .cfg_mmcm_drp_den(cfg_mmcm_drp_den_p0),
  .cfg_mmcm_drp_dwe(cfg_mmcm_drp_dwe_p0),
  .cfg_mmcm_drp_do(cfg_mmcm_drp_do_p0),
  .cfg_mmcm_drp_drdy(cfg_mmcm_drp_drdy_p0),
  .cfg_mmcm_drp_gpio_out(cfg_mmcm_drp_gpio_out_p0),
  .cfg_mmcm_drp_gpio_in(cfg_mmcm_drp_gpio_in_p0),

  .cfg_rx_idelay_clk(cfg_rx_idelay_clk_p0),
  .cfg_rx_idelay_data(cfg_rx_idelay_data_p0),
  .cfg_rx_idelay_addr(cfg_rx_idelay_addr_p0),

  .cfg_port_tx(cfg_port_tx_p0),
  .cfg_port_enable(cfg_port_enable_p0),
  .cfg_port_rxfclk_dis(cfg_port_rxfclk_dis_p0),
  .cfg_port_rxterm_dis(cfg_port_rxterm_dis_p0),

  .hwcfg_port(hwcfg_port_p0),

// PHY statistics
  .stat_rx_frame_err(stat_rx_frame_err_p0),
  .stat_rx_corr(stat_rx_corr_p0),

// DATA I
  .rx_ref_clk(rx_ref_clk_p0),
  .rx_data_clk(rx_data_clk_p0),
  .rx_data_ready(rx_data_ready_p0),
  .rx_data_valid(rx_data_valid_p0),
  .rx_data_s0(rx_data_s0_p0),
  .rx_data_s1(rx_data_s1_p0),
  .rx_data_s2(rx_data_s2_p0),
  .rx_data_s3(rx_data_s3_p0),

// DATA O
  .tx_ref_clk(tx_ref_clk_p0),
  .tx_data_clk(tx_data_clk_p0),
  .tx_data_valid(tx_data_valid_p0),
  .tx_data_ready(tx_data_ready_p0),
  .tx_data_s0(tx_data_s0_p0),
  .tx_data_s1(tx_data_s1_p0),
  .tx_data_s2(tx_data_s2_p0),
  .tx_data_s3(tx_data_s3_p0)
);

wire         cfg_mmcm_drp_dclk_p1;
wire [15:0]  cfg_mmcm_drp_di_p1;
wire [6:0]   cfg_mmcm_drp_daddr_p1;
wire         cfg_mmcm_drp_den_p1;
wire         cfg_mmcm_drp_dwe_p1;
wire [15:0]  cfg_mmcm_drp_do_p1;
wire         cfg_mmcm_drp_drdy_p1;
wire [3:0]   cfg_mmcm_drp_gpio_out_p1;
wire [3:0]   cfg_mmcm_drp_gpio_in_p1;

wire         cfg_rx_idelay_clk_p1;
wire [4:0]   cfg_rx_idelay_data_p1;
wire [3:0]   cfg_rx_idelay_addr_p1;

wire         cfg_port_tx_p1;
wire         cfg_port_enable_p1;
wire         cfg_port_rxfclk_dis_p1;
wire         cfg_port_rxterm_dis_p1;

wire [2:0]   hwcfg_port_p1;

wire [19:0]  stat_rx_frame_err_p1;
wire [19:0]  stat_rx_corr_p1;

wire             rx_ref_clk_p1;
wire             rx_data_clk_p1;
wire             rx_data_ready_p1;
wire             rx_data_valid_p1;
wire [11:0]      rx_data_s0_p1;
wire [11:0]      rx_data_s1_p1;
wire [11:0]      rx_data_s2_p1;
wire [11:0]      rx_data_s3_p1;

// DATA O
wire              tx_ref_clk_p1;
wire              tx_data_clk_p1;
wire              tx_data_valid_p1;
wire              tx_data_ready_p1;
wire [11:0]       tx_data_s0_p1;
wire [11:0]       tx_data_s1_p1;
wire [11:0]       tx_data_s2_p1;
wire [11:0]       tx_data_s3_p1;


xlnx_lms7_lml_phy #(
  .IN_MODE((RX_LML2) ? LML_PHY_RX_MODE : 0),   // 0 - off, 1 - slow, 2 - fast
  .OUT_MODE((RX_LML2) ? 0 : LML_PHY_TX_MODE),  // 0 - off, 1 - slow, 2 - fast
  .IN_FIFO(1)
) lml_rx (
// LMS7 LML port
  .lms_i_txnrx(lms_i_txnrx2),
  .lms_io_iqsel(lms_io_iqsel2),
  .lms_o_mclk(lms_o_mclk2),
  .lms_i_fclk(lms_i_fclk2),
  .lms_io_diq(lms_diq2),

// PHY configuration port
  .cfg_mmcm_drp_dclk(cfg_mmcm_drp_dclk_p1),
  .cfg_mmcm_drp_di(cfg_mmcm_drp_di_p1),
  .cfg_mmcm_drp_daddr(cfg_mmcm_drp_daddr_p1),
  .cfg_mmcm_drp_den(cfg_mmcm_drp_den_p1),
  .cfg_mmcm_drp_dwe(cfg_mmcm_drp_dwe_p1),
  .cfg_mmcm_drp_do(cfg_mmcm_drp_do_p1),
  .cfg_mmcm_drp_drdy(cfg_mmcm_drp_drdy_p1),
  .cfg_mmcm_drp_gpio_out(cfg_mmcm_drp_gpio_out_p1),
  .cfg_mmcm_drp_gpio_in(cfg_mmcm_drp_gpio_in_p1),

  .cfg_rx_idelay_clk(cfg_rx_idelay_clk_p1),
  .cfg_rx_idelay_data(cfg_rx_idelay_data_p1),
  .cfg_rx_idelay_addr(cfg_rx_idelay_addr_p1),

  .cfg_port_tx(cfg_port_tx_p1),
  .cfg_port_enable(cfg_port_enable_p1),
  .cfg_port_rxfclk_dis(cfg_port_rxfclk_dis_p1),
  .cfg_port_rxterm_dis(cfg_port_rxterm_dis_p1),

  .hwcfg_port(hwcfg_port_p1),

// PHY statistics
  .stat_rx_frame_err(stat_rx_frame_err_p1),
  .stat_rx_corr(stat_rx_corr_p1),

// DATA I
  .rx_ref_clk(rx_ref_clk_p1),
  .rx_data_clk(rx_data_clk_p1),
  .rx_data_ready(rx_data_ready_p1),
  .rx_data_valid(rx_data_valid_p1),
  .rx_data_s0(rx_data_s0_p1),
  .rx_data_s1(rx_data_s1_p1),
  .rx_data_s2(rx_data_s2_p1),
  .rx_data_s3(rx_data_s3_p1),

// DATA O
  .tx_ref_clk(tx_ref_clk_p1),
  .tx_data_clk(tx_data_clk_p1),
  .tx_data_valid(tx_data_valid_p1),
  .tx_data_ready(tx_data_ready_p1),
  .tx_data_s0(tx_data_s0_p1),
  .tx_data_s1(tx_data_s1_p1),
  .tx_data_s2(tx_data_s2_p1),
  .tx_data_s3(tx_data_s3_p1)
);

generate
if (LML_PHY_RX_MODE == 1) begin
    BUFG rx_data_clk_p0_buf(.I(rx_ref_clk_p0), .O(rx_data_clk_p0));
    BUFG rx_data_clk_p1_buf(.I(rx_ref_clk_p1), .O(rx_data_clk_p1));
end else begin
    assign rx_data_clk_p1 = rx_ref_clk_p1;
    assign rx_data_clk_p0 = rx_ref_clk_p0;
end
endgenerate

generate
if (LML_PHY_TX_MODE == 1) begin
    BUFG tx_data_clk_p0_buf(.I(tx_ref_clk_p0), .O(tx_data_clk_p0));
    BUFG tx_data_clk_p1_buf(.I(tx_ref_clk_p1), .O(tx_data_clk_p1));
end else begin
    assign tx_data_clk_p0 = tx_ref_clk_p0;
    assign tx_data_clk_p1 = tx_ref_clk_p1;
end
endgenerate


wire lms7_tx_en;
wire rx_sdr_enable;

assign cfg_port_tx_p0     = (RX_LML2) ? 1'b1 : 1'b0; //TX or RX
assign cfg_port_enable_p0 = (RX_LML2) ? lms7_tx_en : rx_sdr_enable;
assign cfg_port_tx_p1     = (RX_LML2) ? 1'b0 : 1'b1; //RX or TX
assign cfg_port_enable_p1 = (RX_LML2) ? rx_sdr_enable : lms7_tx_en;
wire lms7_tx_clk          = (RX_LML2) ? tx_data_clk_p0 : tx_data_clk_p1;
wire lms7_rx_clk          = (RX_LML2) ? rx_data_clk_p1 : rx_data_clk_p0;
wire [19:0] rx_o_rxiq_odd = (RX_LML2) ? stat_rx_frame_err_p1 : stat_rx_frame_err_p0;
wire [19:0] rx_o_rxiq_miss= (RX_LML2) ? stat_rx_corr_p1 : stat_rx_corr_p0;

wire [11:0] lms7_tx_s0;
wire [11:0] lms7_tx_s1;
wire [11:0] lms7_tx_s2;
wire [11:0] lms7_tx_s3;
assign tx_data_valid_p0 = 1'b1;
assign tx_data_s0_p0 = lms7_tx_s0;
assign tx_data_s1_p0 = lms7_tx_s1;
assign tx_data_s2_p0 = lms7_tx_s2;
assign tx_data_s3_p0 = lms7_tx_s3;

assign tx_data_valid_p1 = 1'b1;
assign tx_data_s0_p1 = lms7_tx_s0;
assign tx_data_s1_p1 = lms7_tx_s1;
assign tx_data_s2_p1 = lms7_tx_s2;
assign tx_data_s3_p1 = lms7_tx_s3;

assign rx_data_ready_p0 = 1'b1;
assign rx_data_ready_p1 = 1'b1;

wire        b_rx_valid  = (RX_LML2) ? rx_data_valid_p1 : rx_data_valid_p0;
wire [11:0] b_rx_sdr_bi = (RX_LML2) ? rx_data_s0_p1 : rx_data_s0_p0;
wire [11:0] b_rx_sdr_ai = (RX_LML2) ? rx_data_s1_p1 : rx_data_s1_p0;
wire [11:0] b_rx_sdr_bq = (RX_LML2) ? rx_data_s2_p1 : rx_data_s2_p0;
wire [11:0] b_rx_sdr_aq = (RX_LML2) ? rx_data_s3_p1 : rx_data_s3_p0;

//wire lms7_rx_diq_termdisable;
//wire cfg_port_rxfclk_dis;
wire cfg_rx_idelay_clk;
wire cfg_rx_idelay_data;
wire cfg_rx_idelay_addr;

assign cfg_port_rxfclk_dis_p0 = lms7_rx_fclk_dis;
assign cfg_rx_idelay_clk_p0 = cfg_rx_idelay_clk;
assign cfg_rx_idelay_data_p0 = cfg_rx_idelay_data;
assign cfg_rx_idelay_addr_p0 = cfg_rx_idelay_addr;
assign cfg_port_rxterm_dis_p0 = lms7_rx_diq_termdisable;

assign cfg_port_rxfclk_dis_p1 = lms7_rx_fclk_dis;
assign cfg_rx_idelay_clk_p1 = cfg_rx_idelay_clk;
assign cfg_rx_idelay_data_p1 = cfg_rx_idelay_data;
assign cfg_rx_idelay_addr_p1 = cfg_rx_idelay_addr;
assign cfg_port_rxterm_dis_p1 = lms7_rx_diq_termdisable;


assign cfg_mmcm_drp_dclk_p0 = drp_clk;
assign cfg_mmcm_drp_dclk_p1 = drp_clk;
///////////////////////////////////////////////////////////////////////////////
reg                                         user_reset_q = 1'b1;
reg                                         user_lnk_up_q = 1'b0;

reg [22:0] rx_div_fwd_lck = 0;
always @(posedge lms7_rx_clk) begin
   rx_div_fwd_lck <= rx_div_fwd_lck + 1;
end
reg [22:0] tx_div_fwd_lck = 0;
always @(posedge lms7_tx_clk) begin
   tx_div_fwd_lck <= tx_div_fwd_lck + 1;
end

reg [27:0] cntr2 = 28'hfff_ffff;
always @(posedge  user_clk) begin
  cntr2 <= cntr2 + 1;
end

wire clk_enumerating = cntr2[27] || cntr2[26];               // On-On-On-Off
wire clk_reset       = cntr2[27] && cntr2[26] && cntr2[25];  // Off-..-Off-On

wire led_rx_clk = rx_div_fwd_lck[22];
wire led_tx_clk = tx_div_fwd_lck[22];

wire led_trx_clk = led_rx_clk ^ led_tx_clk;

wire led_diagnostic = (user_reset_q)                    ? clk_reset :
                      (!user_reset_q && !user_lnk_up_q) ? clk_enumerating :
                      led_trx_clk;

// SWITCH
wire        tx_switch_c;
wire [1:0]  rx_switch_c;

OBUF   tx_switch_obuf  (.O(tx_switch),   .I(tx_switch_c));
OBUF   rx_switch0_obuf (.O(rx_switch_1), .I(rx_switch_c[0]));
OBUF   rx_switch1_obuf (.O(rx_switch_2), .I(rx_switch_c[1]));

// UART
wire        uart_rxd, uart_txd;
IBUF   rxd_buf(.O(uart_rxd), .I(gps_txd));
OBUF   txd_buf(.O(gps_rxd),  .I(uart_txd));

// I2C BUS1
wire i2c1_sda_in;
wire i2c1_sda_out_oe;
IOBUF sda_buf ( .IO(i2c1_sda), .I(1'b0), .T(~i2c1_sda_out_oe), .O(i2c1_sda_in));

wire i2c1_scl_in;
wire i2c1_scl_out_oe;
IOBUF scl_buf ( .IO(i2c1_scl), .I(1'b0), .T(~i2c1_scl_out_oe), .O(i2c1_scl_in));

// I2C BUS2
wire i2c2_sda_in;
wire i2c2_sda_out_oe;
IOBUF sda2_buf ( .IO(i2c2_sda), .I(1'b0), .T(~i2c2_sda_out_oe), .O(i2c2_sda_in));

wire i2c2_scl_in;
wire i2c2_scl_out_oe;
IOBUF scl2_buf ( .IO(i2c2_scl), .I(1'b0), .T(~i2c2_scl_out_oe), .O(i2c2_scl_in));


// SIM
wire        sim_mode_out;
wire        sim_enable_out;
wire        sim_clk_out;
wire        sim_reset_out;

wire          sim_data_in;
wire          sim_data_oen;

OBUF   sim_mode_out_obuf   ( .O(sim_mode),   .I(sim_mode_out));
OBUF   sim_enable_out_obuf ( .O(sim_enable), .I(sim_enable_out));
OBUF   sim_clk_out_obuf    ( .O(sim_clk),    .I(sim_clk_out));
OBUF   sim_reset_out_obuf  ( .O(sim_reset),  .I(sim_reset_out));

IOBUF  sim_datal_buf ( .IO(sim_data), .I(1'b0), .T(sim_data_oen), .O(sim_data_in));

// PCIe core
// Wire Declarations
  wire                                        pipe_mmcm_rst_n;
  // Tx
  wire                                        s_axis_tx_tready;
  wire [3:0]                                  s_axis_tx_tuser;
  wire [63:0]                     s_axis_tx_tdata;
  wire [7:0]                      s_axis_tx_tkeep;
  wire                                        s_axis_tx_tlast;
  wire                                        s_axis_tx_tvalid;

  // Rx
  wire [63:0]                     m_axis_rx_tdata;
  wire [7:0]                      m_axis_rx_tkeep;
  wire                                        m_axis_rx_tlast;
  wire                                        m_axis_rx_tvalid;
  wire                                        m_axis_rx_tready;
  wire  [21:0]                                m_axis_rx_tuser;

  wire                                        tx_cfg_gnt;
  wire                                        rx_np_ok;
  wire                                        rx_np_req;
  wire                                        cfg_turnoff_ok;
  wire                                        cfg_trn_pending;
  wire                                        cfg_pm_halt_aspm_l0s;
  wire                                        cfg_pm_halt_aspm_l1;
  wire                                        cfg_pm_force_state_en;
  wire   [1:0]                                cfg_pm_force_state;
  wire                                        cfg_pm_wake;
  wire  [63:0]                                cfg_dsn;

  // Flow Control
  wire [2:0]                                  fc_sel;

  //-------------------------------------------------------
  // Configuration (CFG) Interface
  //-------------------------------------------------------
  wire                                        cfg_err_ecrc;
  wire                                        cfg_err_cor;
  wire                                        cfg_err_ur;
  wire                                        cfg_err_cpl_timeout;
  wire                                        cfg_err_cpl_abort;
  wire                                        cfg_err_cpl_unexpect;
  wire                                        cfg_err_posted;
  wire                                        cfg_err_locked;
  wire                                        cfg_err_atomic_egress_blocked;
  wire                                        cfg_err_internal_cor;
  wire                                        cfg_err_malformed;
  wire                                        cfg_err_mc_blocked;
  wire                                        cfg_err_poisoned;
  wire                                        cfg_err_norecovery;
  wire                                        cfg_err_acs;
  wire                                        cfg_err_internal_uncor;
  wire  [47:0]                                cfg_err_tlp_cpl_header;
  wire [127:0]                                cfg_err_aer_headerlog;
  wire   [4:0]                                cfg_aer_interrupt_msgnum;

  wire                                        cfg_interrupt;
  wire                                        cfg_interrupt_assert;
  wire   [7:0]                                cfg_interrupt_di;
  wire                                        cfg_interrupt_stat;
  wire   [4:0]                                cfg_pciecap_interrupt_msgnum;
  wire   [2:0]                                cfg_interrupt_mmenable;
  wire                                        cfg_interrupt_rdy;
  wire                                        cfg_interrupt_msienable;

  wire                                        cfg_to_turnoff;
  wire   [7:0]                                cfg_bus_number;
  wire   [4:0]                                cfg_device_number;
  wire   [2:0]                                cfg_function_number;

  wire  [31:0]                                cfg_mgmt_di;
  wire   [3:0]                                cfg_mgmt_byte_en;
  wire   [9:0]                                cfg_mgmt_dwaddr;
  wire                                        cfg_mgmt_wr_en;
  wire                                        cfg_mgmt_rd_en;
  wire                                        cfg_mgmt_wr_readonly;

  //-------------------------------------------------------
  // Physical Layer Control and Status (PL) Interface
  //-------------------------------------------------------
  wire                                        pl_directed_link_auton;
  wire [1:0]                                  pl_directed_link_change;
  wire                                        pl_directed_link_speed;
  wire [1:0]                                  pl_directed_link_width;
  wire                                        pl_upstream_prefer_deemph;


// Register Declaration
reg [27:0] phy_clk_cntr = 0;
always @(posedge phy_clk) phy_clk_cntr <= phy_clk_cntr + 1'b1;
wire usb_phy_clk_div = phy_clk_cntr[27];


wire [15:0] cfg_command;

// PCIe configuration
assign fc_sel = 3'b0;

assign tx_cfg_gnt = 1'b1;                        // Always allow transmission of Config traffic within block
assign rx_np_ok = 1'b1;                          // Allow Reception of Non-posted Traffic
assign rx_np_req = 1'b1;                         // Always request Non-posted Traffic if available
assign cfg_pm_wake = 1'b0;                       // Never direct the core to send a PM_PME Message
assign cfg_trn_pending = 1'b0;                   // Never set the transaction pending bit in the Device Status Register
assign cfg_pm_halt_aspm_l0s = 1'b0;              // Allow entry into L0s
assign cfg_pm_halt_aspm_l1 = 1'b0;               // Allow entry into L1
assign cfg_pm_force_state_en  = 1'b0;            // Do not qualify cfg_pm_force_state
assign cfg_pm_force_state  = 2'b00;              // Do not move force core into specific PM state
assign cfg_dsn = 64'h12345678;                   // Assign the input DSN (Device Serial Number)
assign s_axis_tx_tuser[0] = 1'b0;                // Unused for V6
assign s_axis_tx_tuser[1] = 1'b0;                // Error forward packet
assign s_axis_tx_tuser[2] = 1'b0;                // Stream packet
assign s_axis_tx_tuser[3] = 1'b0;                // Transmit source discontinue

assign cfg_err_cor = 1'b0;                       // Never report Correctable Error
assign cfg_err_ur = 1'b0;                        // Never report UR
assign cfg_err_ecrc = 1'b0;                      // Never report ECRC Error
assign cfg_err_cpl_timeout = 1'b0;               // Never report Completion Timeout
assign cfg_err_cpl_abort = 1'b0;                 // Never report Completion Abort
assign cfg_err_cpl_unexpect = 1'b0;              // Never report unexpected completion
assign cfg_err_posted = 1'b0;                    // Never qualify cfg_err_* inputs
assign cfg_err_locked = 1'b0;                    // Never qualify cfg_err_ur or cfg_err_cpl_abort
assign cfg_err_atomic_egress_blocked = 1'b0;     // Never report Atomic TLP blocked
assign cfg_err_internal_cor = 1'b0;              // Never report internal error occurred
assign cfg_err_malformed = 1'b0;                 // Never report malformed error
assign cfg_err_mc_blocked = 1'b0;                // Never report multi-cast TLP blocked
assign cfg_err_poisoned = 1'b0;                  // Never report poisoned TLP received
assign cfg_err_norecovery = 1'b0;                // Never qualify cfg_err_poisoned or cfg_err_cpl_timeout
assign cfg_err_acs = 1'b0;                       // Never report an ACS violation
assign cfg_err_internal_uncor = 1'b0;            // Never report internal uncorrectable error
assign cfg_err_aer_headerlog = 128'h0;           // Zero out the AER Header Log
assign cfg_aer_interrupt_msgnum = 5'b00000;      // Zero out the AER Root Error Status Register
assign cfg_err_tlp_cpl_header = 48'h0;           // Zero out the header information

assign pl_directed_link_change = 2'b00;          // Never initiate link change
assign pl_directed_link_width = 2'b00;           // Zero out directed link width
assign pl_directed_link_speed = 1'b0;            // Zero out directed link speed
assign pl_directed_link_auton = 1'b0;            // Zero out link autonomous input
assign pl_upstream_prefer_deemph = 1'b1;         // Zero out preferred de-emphasis of upstream port

assign cfg_mgmt_di = 32'h0;                      // Zero out CFG MGMT input data bus
assign cfg_mgmt_byte_en = 4'h0;                  // Zero out CFG MGMT byte enables
assign cfg_mgmt_dwaddr = 10'h0;                  // Zero out CFG MGMT 10-bit address port
assign cfg_mgmt_wr_en = 1'b0;                    // Do not write CFG space
assign cfg_mgmt_rd_en = 1'b0;                    // Do not read CFG space
assign cfg_mgmt_wr_readonly = 1'b0;              // Never treat RO bit as RW

assign cfg_turnoff_ok = cfg_to_turnoff; // && s_ul_wready;

wire [15:0] cfg_completer_id      = { cfg_bus_number, cfg_device_number, cfg_function_number };
wire [6:0]  rx_bar_hit            = m_axis_rx_tuser[8:2];
wire        rx_ecrc_err           = m_axis_rx_tuser[0]; // Receive ECRC Error: Indicates the current packet has an ECRC error. Asserted at the packet EOF.
wire        rx_err_fwd            = m_axis_rx_tuser[1]; // When asserted, marks the packet in progress as error-poisoned. Asserted by the core for the entire length of the packet.


// Wires used for external clocking connectivity
wire          pipe_pclk_out;
wire          pipe_txoutclk_in;
//wire [1:0]    pipe_rxoutclk_in;
wire [1:0]    pipe_pclk_sel_in;
wire          pipe_mmcm_lock_out;
wire          pipe_userclk_out;
wire          pipe_dclk_out;


reg           clock_alt_sel = 1'b0;
reg  [23:0]   no_lock = 0;
reg           pipe_mmcm_rst_n_r = 1'b1;

reg           mcu_bootp_r = 0;

always @(posedge cfg_mclk) begin
  if (~sys_rst_n_c) begin
     clock_alt_sel     <= 1'b0;
     no_lock           <= 0;
     pipe_mmcm_rst_n_r <= 1'b1;
     mcu_bootp_r       <= 0;
  end else begin
     if (mcu_bootp_r == 0 && no_lock[7] == 1'b1) begin
       mcu_bootp_r <= 1'b1;
     end

     if (no_lock[23] == 1'b1 && ~clock_alt_sel) begin
       clock_alt_sel     <= ~clock_alt_sel;
       no_lock           <= 0;
       pipe_mmcm_rst_n_r <= 1'b0;
     end else if (!pipe_mmcm_lock_out) begin
       no_lock <= no_lock + 1'b1;
       pipe_mmcm_rst_n_r <= 1'b1;
     end
  end
end

wire reset_sel = (clock_alt_sel) ? ~pipe_mmcm_rst_n_r : user_reset;

always @(posedge user_clk) begin
  user_reset_q  <= reset_sel /*user_reset*/;
  user_lnk_up_q <= user_lnk_up;
end

wire mcu_bootp = mcu_bootp_r && ~user_lnk_up_q;

assign pipe_mmcm_rst_n = pipe_mmcm_rst_n_r;

wire [15:0]  cfg_mmcm_drp_di_p2;
wire [6:0]   cfg_mmcm_drp_daddr_p2;
wire         cfg_mmcm_drp_den_p2;
wire         cfg_mmcm_drp_dwe_p2;
wire [15:0]  cfg_mmcm_drp_do_p2;
wire         cfg_mmcm_drp_drdy_p2;
wire [3:0]   cfg_mmcm_drp_gpio_out_p2;
wire [3:0]   cfg_mmcm_drp_gpio_in_p2;

wire [15:0]  cfg_mmcm_drp_di_p3;
wire [6:0]   cfg_mmcm_drp_daddr_p3;
wire         cfg_mmcm_drp_den_p3;
wire         cfg_mmcm_drp_dwe_p3;
wire [15:0]  cfg_mmcm_drp_do_p3;
wire         cfg_mmcm_drp_drdy_p3;
wire [3:0]   cfg_mmcm_drp_gpio_out_p3;
wire [3:0]   cfg_mmcm_drp_gpio_in_p3;


XADC #(
    // Initializing the XADC Control Registers
    .INIT_40(16'h9000),// Calibration coefficient averaging disabled
    // averaging of 16 selected for external channels
    .INIT_41(16'h2ef0),// Continuous Sequencer Mode, Disable unused ALMs,
    // Enable calibration
    .INIT_42(16'h0400),// Set DCLK divider to 4, ADC = 500Ksps, DCLK = 50MHz
    .INIT_48(16'h4701),// Sequencer channel - enable Temp sensor, VCCINT, VCCAUX,
    // VCCBRAM, and calibration
    .INIT_49(16'h000f),// Sequencer channel - enable aux analog channels 0 - 3
    .INIT_4A(16'h4700),// Averaging enabled for Temp sensor, VCCINT, VCCAUX,
    // VCCBRAM
    .INIT_4B(16'h0000),// No averaging on external channels
    .INIT_4C(16'h0000),// Sequencer Bipolar selection
    .INIT_4D(16'h0000),// Sequencer Bipolar selection
    .INIT_4E(16'h0000),// Sequencer Acq time selection
    .INIT_4F(16'h0000),// Sequencer Acq time selection
    .INIT_50(16'hb5ed),// Temp upper alarm trigger 85°C
    .INIT_51(16'h5999),// Vccint upper alarm limit 1.05V
    .INIT_52(16'hA147),// Vccaux upper alarm limit 1.89V
    .INIT_53(16'h0000),// OT upper alarm limit 125°C using automatic shutdown
    .INIT_54(16'ha93a),// Temp lower alarm reset 60°C
    .INIT_55(16'h5111),// Vccint lower alarm limit 0.95V
    .INIT_56(16'h91Eb),// Vccaux lower alarm limit 1.71V
    .INIT_57(16'hae4e),// OT lower alarm reset 70°C
    .INIT_58(16'h5999),// VCCBRAM upper alarm limit 1.05V
    .INIT_5C(16'h5111) // VCCBRAM lower alarm limit 0.95V
    //.SIM_MONITOR_FILE("sensor_input.txt")
    // Analog Stimulus file. Analog input values for simulation
) XADC_INST (          // Connect up instance IO. See UG480 for port descriptions
    .CONVST(0),  // not used
    .CONVSTCLK(0), // not used
    .DADDR(cfg_mmcm_drp_daddr_p3),
    .DCLK(drp_clk),
    .DEN(cfg_mmcm_drp_den_p3),
    .DI(cfg_mmcm_drp_di_p3),
    .DWE(cfg_mmcm_drp_dwe_p3),
    .RESET(cfg_mmcm_drp_gpio_out_p3[0]),
    .VAUXN(),
    .VAUXP(),
    .ALM(),
    .BUSY(cfg_mmcm_drp_gpio_in_p3[0]),
    .CHANNEL(),
    .DO(cfg_mmcm_drp_do_p3),
    .DRDY(cfg_mmcm_drp_drdy_p3),
    .EOC(cfg_mmcm_drp_gpio_in_p3[1]),
    .EOS(cfg_mmcm_drp_gpio_in_p3[2]),
    .JTAGBUSY(),// not used
    .JTAGLOCKED(),// not used
    .JTAGMODIFIED(),// not used
    .OT(cfg_mmcm_drp_gpio_in_p3[3]),
    .MUXADDR(),// not used
    .VP(),
    .VN()
);

xlnx_pci_clocking #(
    .PCIE_GEN1_MODE(0)
) xlnx_pci_clocking (
    //---------- Input -------------------------------------
    .CLK_RST_N(pipe_mmcm_rst_n),
    .CLK_TXOUTCLK(pipe_txoutclk_in),
    .CLK_PCLK_SEL(pipe_pclk_sel_in),

    //---------- Output ------------------------------------
    .CLK_PCLK(pipe_pclk_out),
    .CLK_DCLK(pipe_dclk_out),
    .CLK_USERCLK(pipe_userclk_out),
    .CLK_MMCM_LOCK(pipe_mmcm_lock_out),

    //-- OUR SPECIFIC CLOCKS
    .alt_refclk(1'b0 /*cfg_mclk*/),
    .alt_refclk_use(1'b0 /*clock_alt_sel*/),

    .clk_50mhz_out(clk_50mhz_out),

  .cfg_mmcm_drp_dclk(drp_clk),
  .cfg_mmcm_drp_di(cfg_mmcm_drp_di_p2),
  .cfg_mmcm_drp_daddr(cfg_mmcm_drp_daddr_p2),
  .cfg_mmcm_drp_den(cfg_mmcm_drp_den_p2),
  .cfg_mmcm_drp_dwe(cfg_mmcm_drp_dwe_p2),
  .cfg_mmcm_drp_do(cfg_mmcm_drp_do_p2),
  .cfg_mmcm_drp_drdy(cfg_mmcm_drp_drdy_p2),
  .cfg_mmcm_drp_gpio_out(cfg_mmcm_drp_gpio_out_p2),
  .cfg_mmcm_drp_gpio_in(cfg_mmcm_drp_gpio_in_p2)
);

wire pipe_oobclk_out = pipe_pclk_out;
wire pipe_rxusrclk_out = pipe_pclk_out;

//wire user_clk;
wire user_clk_pcie;

BUFGMUX userclk_c_bufg(
    .I0(user_clk_pcie),
    .I1(cfg_mclk),
    .S(clock_alt_sel),
    .O(user_clk)
);


wire [15:0] cfg_pcie_ctrl_reg; //Device Control Register (Offset 08h)

wire [2:0] cfg_max_read_req_size = cfg_pcie_ctrl_reg[14:12];
wire       cfg_no_snoop_enable   = cfg_pcie_ctrl_reg[11];
wire       cfg_ext_tag_enabled   = cfg_pcie_ctrl_reg[8];
wire [2:0] cfg_max_payload_size  = cfg_pcie_ctrl_reg[7:5];
wire       cfg_relax_ord_enabled = cfg_pcie_ctrl_reg[4];


pcie_7x_0   ac701_pcie_x4_gen2_support_i(
    //----------------------------------------------------------------------------------------------------------------//
    // PCI Express (pci_exp) Interface                                                                                //
    //----------------------------------------------------------------------------------------------------------------//
    // Tx
    .pci_exp_txn                               ( pci_exp_txn ),
    .pci_exp_txp                               ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                               ( pci_exp_rxn ),
    .pci_exp_rxp                               ( pci_exp_rxp ),

    // Shared clock interface
    .pipe_pclk_in(pipe_pclk_out),
    .pipe_rxusrclk_in(pipe_rxusrclk_out),
    .pipe_rxoutclk_in(2'b00),
    .pipe_mmcm_rst_n(pipe_mmcm_rst_n),
    .pipe_dclk_in(pipe_dclk_out),
    .pipe_userclk1_in(pipe_userclk_out),
    .pipe_userclk2_in(pipe_userclk_out),
    .pipe_oobclk_in( pipe_oobclk_out ),
    .pipe_mmcm_lock_in(pipe_mmcm_lock_out),
    .pipe_txoutclk_out(pipe_txoutclk_in),
    .pipe_rxoutclk_out(),
    .pipe_pclk_sel_out(pipe_pclk_sel_in),
    .pipe_gen3_out(),


    //----------------------------------------------------------------------------------------------------------------//
    // AXI-S Interface                                                                                                //
    //----------------------------------------------------------------------------------------------------------------//
    // Common
    .user_clk_out                              ( user_clk_pcie ),
    .user_reset_out                            ( user_reset ),
    .user_lnk_up                               ( user_lnk_up ),
    .user_app_rdy                              ( ),

    // TX
    .s_axis_tx_tready                          ( s_axis_tx_tready ),
    .s_axis_tx_tdata                           ( s_axis_tx_tdata ),
    .s_axis_tx_tkeep                           ( s_axis_tx_tkeep ),
    .s_axis_tx_tuser                           ( s_axis_tx_tuser ),
    .s_axis_tx_tlast                           ( s_axis_tx_tlast ),
    .s_axis_tx_tvalid                          ( s_axis_tx_tvalid ),

    // Rx
    .m_axis_rx_tdata                           ( m_axis_rx_tdata ),
    .m_axis_rx_tkeep                           ( m_axis_rx_tkeep ),
    .m_axis_rx_tlast                           ( m_axis_rx_tlast ),
    .m_axis_rx_tvalid                          ( m_axis_rx_tvalid ),
    .m_axis_rx_tready                          ( m_axis_rx_tready ),
    .m_axis_rx_tuser                           ( m_axis_rx_tuser ),

    .tx_cfg_gnt                                ( tx_cfg_gnt ),
    .rx_np_ok                                  ( rx_np_ok ),
    .rx_np_req                                 ( rx_np_req ),
    .cfg_trn_pending                           ( cfg_trn_pending ),
    .cfg_pm_halt_aspm_l0s                      ( cfg_pm_halt_aspm_l0s ),
    .cfg_pm_halt_aspm_l1                       ( cfg_pm_halt_aspm_l1 ),
    .cfg_pm_force_state_en                     ( cfg_pm_force_state_en ),
    .cfg_pm_force_state                        ( cfg_pm_force_state ),
    .cfg_dsn                                   ( cfg_dsn ),
    .cfg_turnoff_ok                            ( cfg_turnoff_ok ),
    .cfg_pm_wake                               ( cfg_pm_wake ),
    .cfg_pm_send_pme_to                        ( 1'b0 ),
    .cfg_ds_bus_number                         ( 8'b0 ),
    .cfg_ds_device_number                      ( 5'b0 ),
    .cfg_ds_function_number                    ( 3'b0 ),

    //----------------------------------------------------------------------------------------------------------------//
    // Flow Control Interface                                                                                         //
    //----------------------------------------------------------------------------------------------------------------//
    .fc_cpld                                   ( ),
    .fc_cplh                                   ( ),
    .fc_npd                                    ( ),
    .fc_nph                                    ( ),
    .fc_pd                                     ( ),
    .fc_ph                                     ( ),
    .fc_sel                                    ( fc_sel ),

    //----------------------------------------------------------------------------------------------------------------//
    // Configuration (CFG) Interface                                                                                  //
    //----------------------------------------------------------------------------------------------------------------//
    .cfg_device_number                         ( cfg_device_number ),
    .cfg_dcommand2                             ( ),
    .cfg_pmcsr_pme_status                      ( ),
    .cfg_status                                ( ),
    .cfg_to_turnoff                            ( cfg_to_turnoff ),
    .cfg_received_func_lvl_rst                 ( ),
    .cfg_dcommand                              ( cfg_pcie_ctrl_reg ),
    .cfg_bus_number                            ( cfg_bus_number ),
    .cfg_function_number                       ( cfg_function_number ),
    .cfg_command                               ( cfg_command ),
    .cfg_dstatus                               ( ),
    .cfg_lstatus                               ( ),
    .cfg_pcie_link_state                       ( ),
    .cfg_lcommand                              ( ),
    .cfg_pmcsr_pme_en                          ( ),
    .cfg_pmcsr_powerstate                      ( ),
    .tx_buf_av                                 ( ),
    .tx_err_drop                               ( ),
    .tx_cfg_req                                ( ),
    //------------------------------------------------//
    // RP Only                                        //
    //------------------------------------------------//
    .cfg_bridge_serr_en                        ( ),
    .cfg_slot_control_electromech_il_ctl_pulse ( ),
    .cfg_root_control_syserr_corr_err_en       ( ),
    .cfg_root_control_syserr_non_fatal_err_en  ( ),
    .cfg_root_control_syserr_fatal_err_en      ( ),
    .cfg_root_control_pme_int_en               ( ),
    .cfg_aer_rooterr_corr_err_reporting_en     ( ),
    .cfg_aer_rooterr_non_fatal_err_reporting_en( ),
    .cfg_aer_rooterr_fatal_err_reporting_en    ( ),
    .cfg_aer_rooterr_corr_err_received         ( ),
    .cfg_aer_rooterr_non_fatal_err_received    ( ),
    .cfg_aer_rooterr_fatal_err_received        ( ),

    //----------------------------------------------------------------------------------------------------------------//
    // VC interface                                                                                                   //
    //----------------------------------------------------------------------------------------------------------------//
    .cfg_vc_tcvc_map                           ( ),

    // Management Interface
    .cfg_mgmt_di                               ( cfg_mgmt_di ),
    .cfg_mgmt_byte_en                          ( cfg_mgmt_byte_en ),
    .cfg_mgmt_dwaddr                           ( cfg_mgmt_dwaddr ),
    .cfg_mgmt_wr_en                            ( cfg_mgmt_wr_en ),
    .cfg_mgmt_rd_en                            ( cfg_mgmt_rd_en ),
    .cfg_mgmt_wr_readonly                      ( cfg_mgmt_wr_readonly ),
    .cfg_mgmt_wr_rw1c_as_rw                    ( 1'b0 ),
    //------------------------------------------------//
    // EP and RP                                      //
    //------------------------------------------------//
    .cfg_mgmt_do                               ( ),
    .cfg_mgmt_rd_wr_done                       ( ),

    // Error Reporting Interface
    .cfg_err_ecrc                              ( cfg_err_ecrc ),
    .cfg_err_ur                                ( cfg_err_ur ),
    .cfg_err_cpl_timeout                       ( cfg_err_cpl_timeout ),
    .cfg_err_cpl_unexpect                      ( cfg_err_cpl_unexpect ),
    .cfg_err_cpl_abort                         ( cfg_err_cpl_abort ),
    .cfg_err_posted                            ( cfg_err_posted ),
    .cfg_err_cor                               ( cfg_err_cor ),
    .cfg_err_atomic_egress_blocked             ( cfg_err_atomic_egress_blocked ),
    .cfg_err_internal_cor                      ( cfg_err_internal_cor ),
    .cfg_err_malformed                         ( cfg_err_malformed ),
    .cfg_err_mc_blocked                        ( cfg_err_mc_blocked ),
    .cfg_err_poisoned                          ( cfg_err_poisoned ),
    .cfg_err_norecovery                        ( cfg_err_norecovery ),
    .cfg_err_tlp_cpl_header                    ( cfg_err_tlp_cpl_header ),
    .cfg_err_cpl_rdy                           ( ),
    .cfg_err_locked                            ( cfg_err_locked ),
    .cfg_err_acs                               ( cfg_err_acs ),
    .cfg_err_internal_uncor                    ( cfg_err_internal_uncor ),
    //----------------------------------------------------------------------------------------------------------------//
    // AER Interface                                                                                                  //
    //----------------------------------------------------------------------------------------------------------------//
    .cfg_err_aer_headerlog                     ( cfg_err_aer_headerlog ),
    .cfg_aer_interrupt_msgnum                  ( cfg_aer_interrupt_msgnum ),
    .cfg_err_aer_headerlog_set                 ( ),
    .cfg_aer_ecrc_check_en                     ( ),
    .cfg_aer_ecrc_gen_en                       ( ),

    //------------------------------------------------//
    // EP Only                                        //
    //------------------------------------------------//
    .cfg_interrupt                             ( cfg_interrupt ),
    .cfg_interrupt_rdy                         ( cfg_interrupt_rdy ),
    .cfg_interrupt_assert                      ( cfg_interrupt_assert ),
    .cfg_interrupt_di                          ( cfg_interrupt_di ),
    .cfg_interrupt_do                          ( ),
    .cfg_interrupt_mmenable                    ( cfg_interrupt_mmenable ),
    .cfg_interrupt_msienable                   ( cfg_interrupt_msienable ),
    .cfg_interrupt_msixenable                  ( ),
    .cfg_interrupt_msixfm                      ( ),
    .cfg_interrupt_stat                        ( cfg_interrupt_stat ),
    .cfg_pciecap_interrupt_msgnum              ( cfg_pciecap_interrupt_msgnum ),

    .cfg_msg_received_err_cor                  ( ),
    .cfg_msg_received_err_non_fatal            ( ),
    .cfg_msg_received_err_fatal                ( ),
    .cfg_msg_received_pm_as_nak                ( ),
    .cfg_msg_received_pme_to_ack               ( ),
    .cfg_msg_received_assert_int_a             ( ),
    .cfg_msg_received_assert_int_b             ( ),
    .cfg_msg_received_assert_int_c             ( ),
    .cfg_msg_received_assert_int_d             ( ),
    .cfg_msg_received_deassert_int_a           ( ),
    .cfg_msg_received_deassert_int_b           ( ),
    .cfg_msg_received_deassert_int_c           ( ),
    .cfg_msg_received_deassert_int_d           ( ),

    .cfg_msg_received_pm_pme                   ( ),
    .cfg_msg_received_setslotpowerlimit        ( ),
    .cfg_msg_received                          ( ),
    .cfg_msg_data                              ( ),

    //----------------------------------------------------------------------------------------------------------------//
    // Physical Layer Control and Status (PL) Interface                                                               //
    //----------------------------------------------------------------------------------------------------------------//
    .pl_directed_link_change                   ( pl_directed_link_change ),
    .pl_directed_link_width                    ( pl_directed_link_width ),
    .pl_directed_link_speed                    ( pl_directed_link_speed ),
    .pl_directed_link_auton                    ( pl_directed_link_auton ),
    .pl_upstream_prefer_deemph                 ( pl_upstream_prefer_deemph ),

    .pl_sel_lnk_rate                           ( ),
    .pl_sel_lnk_width                          ( ),
    .pl_ltssm_state                            ( ),
    .pl_lane_reversal_mode                     ( ),

    .pl_phy_lnk_up                             ( ),
    .pl_tx_pm_state                            ( ),
    .pl_rx_pm_state                            ( ),

    .pl_link_upcfg_cap                         ( ),
    .pl_link_gen2_cap                          ( ),
    .pl_link_partner_gen2_supported            ( ),
    .pl_initial_link_width                     ( ),

    .pl_directed_change_done                   ( ),

    //------------------------------------------------//
    // EP Only                                        //
    //------------------------------------------------//
    .pl_received_hot_rst                       ( ),

    //------------------------------------------------//
    // RP Only                                        //
    //------------------------------------------------//
    .pl_transmit_hot_rst                       ( 1'b0 ),
    .pl_downstream_deemph_source               ( 1'b0 ),

    //----------------------------------------------------------------------------------------------------------------//
    // PCIe DRP (PCIe DRP) Interface                                                                                  //
    //----------------------------------------------------------------------------------------------------------------//
    .pcie_drp_clk                               ( 1'b1 ),
    .pcie_drp_en                                ( 1'b0 ),
    .pcie_drp_we                                ( 1'b0 ),
    .pcie_drp_addr                              ( 9'h0 ),
    .pcie_drp_di                                ( 16'h0 ),
    .pcie_drp_rdy                               ( ),
    .pcie_drp_do                                ( ),

    //----------------------------------------------------------------------------------------------------------------//
    // System  (SYS) Interface                                                                                        //
    //----------------------------------------------------------------------------------------------------------------//
    .sys_clk                                    ( sys_clk ),
    .sys_rst_n                                  ( sys_rst_n_c )

);

// v3_app

v3_pcie_app #(
  .UL_BUS_SPEED(32'd125_000_000),
  .NO_PPS(NO_PPS),
  .NO_GTIME(NO_GTIME),
  .FLASH_ASYNC_CLOCKS(FLASH_ASYNC_CLOCKS),
  .FW_ID(XTRX_FW_ID),
  .COMPAT_ID(XTRX_COMPAT_ID)
) app (
  // Common
  .user_clk( user_clk ),
  .user_reset( user_reset_q ),
  .user_lnk_up( user_lnk_up_q ),

  .mcu_bootp(mcu_bootp),

  // Tx
  .s_axis_tx_tready(s_axis_tx_tready),
  .s_axis_tx_tdata(s_axis_tx_tdata),
  .s_axis_tx_tkeep(s_axis_tx_tkeep),
  .s_axis_tx_tlast(s_axis_tx_tlast),
  .s_axis_tx_tvalid(s_axis_tx_tvalid),

  // Rx
  .m_axis_rx_tdata(m_axis_rx_tdata),
  .m_axis_rx_tkeep(m_axis_rx_tkeep),
  .m_axis_rx_tlast(m_axis_rx_tlast),
  .m_axis_rx_tvalid(m_axis_rx_tvalid),
  .m_axis_rx_tready(m_axis_rx_tready),
  .pcie_rx_bar_hit(rx_bar_hit),

  // PCIe extra logic
  .pcie_cfg_completer_id(cfg_completer_id),

  // PCIe interrupt logic
  .cfg_interrupt(cfg_interrupt),
  .cfg_interrupt_assert(cfg_interrupt_assert),
  .cfg_interrupt_di(cfg_interrupt_di),
  .cfg_interrupt_stat(cfg_interrupt_stat),
  .cfg_pciecap_interrupt_msgnum(cfg_pciecap_interrupt_msgnum),
  .cfg_interrupt_mmenable(cfg_interrupt_mmenable),
  .cfg_interrupt_rdy(cfg_interrupt_rdy),
  .cfg_interrupt_msienable(cfg_interrupt_msienable),
  .legacy_interrupt_disabled(cfg_command[10]),

  .cfg_max_read_req_size(cfg_max_read_req_size),
  .cfg_no_snoop_enable(cfg_no_snoop_enable),
  .cfg_ext_tag_enabled(cfg_ext_tag_enabled),
  .cfg_max_payload_size(cfg_max_payload_size),
  .cfg_relax_ord_enabled(cfg_relax_ord_enabled),

  .xtrx_ctrl_lines(xtrx_ctrl_lines),
  .xtrx_i2c_lut(xtrx_i2c_lut),

  .lms7_mosi(lms7_mosi),
  .lms7_miso(lms7_miso),
  .lms7_sck(lms7_sck),
  .lms7_sen(lms7_sen),

   // PORT 1
  .lms7_rx_clk(lms7_rx_clk),
  .lms7_rx_ai(b_rx_sdr_ai),
  .lms7_rx_aq(b_rx_sdr_aq),
  .lms7_rx_bi(b_rx_sdr_bi),
  .lms7_rx_bq(b_rx_sdr_bq),
  .lms7_rx_valid(b_rx_valid),
  .lms7_rxiq_miss(rx_o_rxiq_miss),
  .lms7_rxiq_odd(rx_o_rxiq_odd),
  .lms7_rxiq_period(0),
  .lms7_rx_enable(rx_sdr_enable),
  .lms7_rx_delay_clk(cfg_rx_idelay_clk),
  .lms7_rx_delay_idx(cfg_rx_idelay_addr),
  .lms7_rx_delay(cfg_rx_idelay_data),

   // PORT 2
  .lms7_tx_clk(lms7_tx_clk),
  .lms7_tx_ai(lms7_tx_s1),
  .lms7_tx_aq(lms7_tx_s3),
  .lms7_tx_bi(lms7_tx_s0),
  .lms7_tx_bq(lms7_tx_s2),
  .lms7_tx_en(lms7_tx_en),

  .lms7_lml1_phy_hwid({ 1'b0, hwcfg_port_p0 }),
  .lms7_lml2_phy_hwid({ 1'b0, hwcfg_port_p1 }),

  .rx_running(rx_running),
  .tx_running(tx_running),

  .tx_switch(tx_switch_c),
  .rx_switch(rx_switch_c),

  .uart_rxd(uart_rxd),
  .uart_txd(uart_txd),

  .sda1_in(i2c1_sda_in),
  .sda1_out_eo(i2c1_sda_out_oe),
  .scl1_out_eo(i2c1_scl_out_oe),

  .sda2_in(i2c2_sda_in),
  .sda2_out_eo(i2c2_sda_out_oe),
  .scl2_out_eo(i2c2_scl_out_oe),

  .osc_clk(fpga_clk_vctcxo_buf),
  .onepps(onepps),

  .sim_mode_out(sim_mode_out),
  .sim_enable_out(sim_enable_out),
  .sim_clk_out(sim_clk_out),
  .sim_reset_out(sim_reset_out),

  .sim_data_in(sim_data_in),
  .sim_data_oen(sim_data_oen),

  // Flash interface
  .flash_dout(flash_dout),
  .flash_din(flash_din),
  .flash_ndrive(flash_ndrive),
  .flash_ncs(flash_ncs),
  .flash_cclk(flash_cclk),

  .phy_clk(phy_clk),

  .phy_nrst(phy_nrst),
  .phy_do(phy_do),
  .phy_di(phy_di),
  .phy_doe(phy_doe),

  .phy_dir(phy_dir),
  .phy_nxt(phy_nxt),
  .phy_stp(phy_stp),

  // GPIO
  .gpio_se_gpio_oe(xtrx_gpio_oe),
  .gpio_se_gpio_out(xtrx_gpio_out),
  .gpio_se_gpio_in(xtrx_gpio_in),
  .gpio5_alt1_usr_rstn(!user_reset_q),
  .gpio6_alt1_pci_rstn(sys_rst_n_c),
  .gpio7_alt1_trouble(usb_phy_clk_div),
  .gpio12_alt1_stat(led_diagnostic),
  .gpio12_alt2_rx(led_rx_clk),
  .gpio12_alt3_tx(led_tx_clk),

  .drp_clk(drp_clk),

  // DRP port0
  .drp_di_0(cfg_mmcm_drp_di_p0),
  .drp_daddr_0(cfg_mmcm_drp_daddr_p0),
  .drp_den_0(cfg_mmcm_drp_den_p0),
  .drp_dwe_0(cfg_mmcm_drp_dwe_p0),
  .drp_do_0(cfg_mmcm_drp_do_p0),
  .drp_drdy_0(cfg_mmcm_drp_drdy_p0),

  .drp_gpio_out_0(cfg_mmcm_drp_gpio_out_p0),
  .drp_gpio_in_0(cfg_mmcm_drp_gpio_in_p0),

  // DRP port1
  .drp_di_1(cfg_mmcm_drp_di_p1),
  .drp_daddr_1(cfg_mmcm_drp_daddr_p1),
  .drp_den_1(cfg_mmcm_drp_den_p1),
  .drp_dwe_1(cfg_mmcm_drp_dwe_p1),
  .drp_do_1(cfg_mmcm_drp_do_p1),
  .drp_drdy_1(cfg_mmcm_drp_drdy_p1),

  .drp_gpio_out_1(cfg_mmcm_drp_gpio_out_p1),
  .drp_gpio_in_1(cfg_mmcm_drp_gpio_in_p1),

  // DRP port2
  .drp_di_2(cfg_mmcm_drp_di_p2),
  .drp_daddr_2(cfg_mmcm_drp_daddr_p2),
  .drp_den_2(cfg_mmcm_drp_den_p2),
  .drp_dwe_2(cfg_mmcm_drp_dwe_p2),
  .drp_do_2(cfg_mmcm_drp_do_p2),
  .drp_drdy_2(cfg_mmcm_drp_drdy_p2),

  .drp_gpio_out_2(cfg_mmcm_drp_gpio_out_p2),
  .drp_gpio_in_2(cfg_mmcm_drp_gpio_in_p2),

  // DRP port3
  .drp_di_3(cfg_mmcm_drp_di_p3),
  .drp_daddr_3(cfg_mmcm_drp_daddr_p3),
  .drp_den_3(cfg_mmcm_drp_den_p3),
  .drp_dwe_3(cfg_mmcm_drp_dwe_p3),
  .drp_do_3(cfg_mmcm_drp_do_p3),
  .drp_drdy_3(cfg_mmcm_drp_drdy_p3),

  .drp_gpio_out_3(cfg_mmcm_drp_gpio_out_p3),
  .drp_gpio_in_3(cfg_mmcm_drp_gpio_in_p3)

);

endmodule

