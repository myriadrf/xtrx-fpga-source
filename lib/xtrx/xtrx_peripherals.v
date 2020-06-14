//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module xtrx_peripherals #(
  parameter UL_BUS_LEN = 10,
  parameter BUFFER_BUS_ADDRESS = 32,
  parameter BUFFER_SIZE_RX_BITS = 16,
  parameter BUFFER_SIZE_TX_BITS = 17,
  parameter MEM_TAG          = 5,
  parameter PHY_DIAG_BITS    = 32,
  parameter TS_BITS          = 30,
  parameter UL_BUS_SPEED     = 32'd125_000_000,
  parameter GPS_UART_SPEED   = 32'd0_____9_600,
  parameter TMP102_I2C_SPEED = 32'd0___100_000,
  parameter SIM_SPEED        = 32'd0_4_000_000,
  parameter LMS7_SPI_SPEED   = 32'd040_000_000,
  parameter NO_UART          = 0,
  parameter NO_SMART_CARD    = 0,
  parameter NO_TEMP          = 0,
  parameter NO_PPS           = 0,
  parameter NO_GTIME         = 0,
  parameter FLASH_ASYNC_CLOCKS = 1
)(
  input clk,
  input rst,

  // UL Write channel
  input [UL_BUS_LEN - 1:0]  s_ul_waddr,
  input [31:0]              s_ul_wdata,
  input                     s_ul_wvalid,
  output                    s_ul_wready,

  // UL Read address channel
  input [UL_BUS_LEN - 1:0]  s_ul_araddr,
  input                     s_ul_arvalid,
  output                    s_ul_arready,

  // UL Read data channel signals
  output [31:0]             s_ul_rdata,
  output                    s_ul_rvalid,
  input                     s_ul_rready,

  // HWCFG DATA
  input [31:0]              hwcfg,
  input [31:0]              xtrx_i2c_lut,

  // PCIe Interrupts
  output           cfg_interrupt,
  output           cfg_interrupt_assert,
  output [7:0]     cfg_interrupt_di,
  output           cfg_interrupt_stat,
  output [4:0]     cfg_pciecap_interrupt_msgnum,
  input [2:0]      cfg_interrupt_mmenable,
  input            cfg_interrupt_rdy,
  input            cfg_interrupt_msienable,
  input            legacy_interrupt_disabled,
  input [2:0]      cfg_max_read_req_size,
  input [2:0]      cfg_max_payload_size,

  //
  // RX FE Ctrl
  //
  input [PHY_DIAG_BITS-1:0] rxfe0_phy_iq_miss,
  input [PHY_DIAG_BITS-1:0] rxfe0_phy_iq_odd,
  input [PHY_DIAG_BITS-1:0] rxfe0_phy_iq_period,

  input [2:0]               rxfe0_bufpos,
  input                     rxfe0_resume,
  output [7:0]              rxfe0_ctrl,

  output [31:0]             rxfe0_cmd_data,
  output                    rxfe0_cmd_valid,
  input                     rxfe0_cmd_ready,

  input [TS_BITS-1:0]       rxfeX_ts_current,

  input                     ts_clk,
  input [TS_BITS-1:0]       ts_current,
  input                     ts_command_rxfrm_ready,
  output                    ts_command_rxfrm_valid,

  //
  // TX FE Ctrl
  //
  input                      txfe0_mclk,
  output                     txfe0_arst,
  output                     txfe0_mode_siso,
  output                     txfe0_mode_repeat,
  output [2:0]               txfe0_mode_interp,
  input [1:0]                txfe0_debug_fe_state,
  input [BUFFER_SIZE_TX_BITS-1:3] txfe0_debug_rd_addr,

  input                      txfe0_ts_rd_addr_inc,
  input [TS_BITS-1:0]        txfe0_ts_rd_addr_late_samples,

  input                      txfe0_ts_rd_addr_processed_inc,
  output                     txfe0_ts_rd_valid,   // Valid start time & No of samples
  output [TS_BITS-1:0]       txfe0_ts_rd_start,
  output [BUFFER_SIZE_TX_BITS-1:3]txfe0_ts_rd_samples,
  input [TS_BITS-1:0]        txfe0_ts_current,

  output                     txfe0_out_rd_rst,
  output                     txfe0_out_rd_clk,
  input [BUFFER_SIZE_TX_BITS:7]   txfe0_out_rd_addr,

  output                     tx_running,
  //
  // Bus data move request (L->R)
  output                            ul_lm_rvalid,
  input                             ul_lm_rready,
  output [BUFFER_SIZE_RX_BITS - 1:3]ul_lm_rlocaddr,
  output [BUFFER_BUS_ADDRESS - 1:3] ul_lm_rbusaddr,
  output [4:0]                      ul_lm_rlength,
  output [MEM_TAG-1:0]              ul_lm_rtag,
  // Bus data move confirmation
  input                             ul_lm_tvalid,
  output                            ul_lm_tready,
  input [MEM_TAG-1:0]               ul_lm_ttag,

  //
  // Bus data move request (R->L)
  output                            ul_ml_rvalid,
  input                             ul_ml_rready,
  output [BUFFER_SIZE_TX_BITS-1:3]  ul_ml_rlocaddr,
  output [BUFFER_BUS_ADDRESS - 1:3] ul_ml_rbusaddr,
  output [8:0]                      ul_ml_rlength,
  output [MEM_TAG-1:0]              ul_ml_rtag,

  input                             ul_ml_tvalid,
  output                            ul_ml_tready,
  input [MEM_TAG-1:0]               ul_ml_ttag,


  // RFIC CTRL & SPI
  output [15:0]             rfic_gpio,
  output [11:0]             rfic_ddr_ctrl,
  output                    rfic_mosi,
  input                     rfic_miso,
  output                    rfic_sck,
  output                    rfic_sen,

  //
  // RF Switches
  output          tx_switch,
  output [1:0]    rx_switch,

  // GPS
  input           uart_rxd,
  output          uart_txd,

  // I2C CH0
  input           sda1_in,
  output          sda1_out_eo,
  output          scl1_out_eo,

  // I2C CH1
  input           sda2_in,
  output          sda2_out_eo,
  output          scl2_out_eo,

  // 1PPS
  input           osc_clk,
  input           onepps,

  // SIM
  output          sim_mode_out,
  output          sim_enable_out,
  output          sim_clk_out,
  output          sim_reset_out,

  input           sim_data_in,
  output          sim_data_oen,

  // QSPI FLASH
  output [3:0]    flash_dout,
  input  [3:0]    flash_din,
  output [3:0]    flash_ndrive,
  output          flash_ncs,
  input           flash_cclk,

  // USB2 PHY
  input        phy_clk,

  output       phy_nrst,
  output [7:0] phy_do,
  input  [7:0] phy_di,
  output       phy_doe,

  input        phy_dir,
  input        phy_nxt,
  output       phy_stp,

  // GPIO ctrl_if
  output [13:0] gpio_se_gpio_oe,
  output [13:0] gpio_se_gpio_out,
  input  [13:0] gpio_se_gpio_in,
  input         gpio5_alt1_usr_rstn,
  input         gpio6_alt1_pci_rstn,
  input         gpio7_alt1_trouble,
  input         gpio12_alt1_stat,
  input         gpio12_alt2_rx,
  input         gpio12_alt3_tx,

  // DRPs if
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
  input  [3:0]  drp_gpio_in_3,

  //TODO REMOVE THESE
  output        txdma_active,
  input         rx_running
);

localparam TIMED_FRAC_BITS = 26;
localparam TIMED_SEC_BITS = 32;

///////////////////////////////////////////////////////////////////////////////
//    WR           |        RD
// ----------------+----------------
// M0 - GO         |    GO
// M1 - BUF_MEM    |    GO
// M2 - RX DMA     |    BUF_MEM
// M3 - TX DMA     |    BUF_MEM
///////////////////////////////////////////////////////////////////////////////

wire [UL_BUS_LEN-3:0]  m0_ul_waddr;
wire [31:0]            m0_ul_wdata;
wire                   m0_ul_wvalid;
wire                   m0_ul_wready;

wire [UL_BUS_LEN-3:0]  m1_ul_waddr;
wire [31:0]            m1_ul_wdata;
wire                   m1_ul_wvalid;
wire                   m1_ul_wready;

wire [UL_BUS_LEN-3:0]  m2_ul_waddr;
wire [31:0]            m2_ul_wdata;
wire                   m2_ul_wvalid;
wire                   m2_ul_wready;

wire [UL_BUS_LEN-3:0]  m3_ul_waddr;
wire [31:0]            m3_ul_wdata;
wire                   m3_ul_wvalid;
wire                   m3_ul_wready;

// Timed master
wire [UL_BUS_LEN-1:0]  st_ul_waddr;
wire [31:0]            st_ul_wdata;
wire                   st_ul_wvalid;
wire                   st_ul_wready;

ul_router4_wr #(
  .ADDR_WIDTH(UL_BUS_LEN)
) ul_router4_wr (
    .s_ul_clk(clk),
    .s_ul_aresetn(~rst),

    // UL Write channel 0
    .s0_ul_waddr(s_ul_waddr),
    .s0_ul_wdata(s_ul_wdata),
    .s0_ul_wvalid(s_ul_wvalid),
    .s0_ul_wready(s_ul_wready),

    // UL Write channel 1
    .s1_ul_waddr(st_ul_waddr),
    .s1_ul_wdata(st_ul_wdata),
    .s1_ul_wvalid(st_ul_wvalid),
    .s1_ul_wready(st_ul_wready),

    // UL Write channel 2
    .s2_ul_waddr(0),
    .s2_ul_wdata(0),
    .s2_ul_wvalid(0),
    .s2_ul_wready(),

    // UL Write channel 3
    .s3_ul_waddr(0),
    .s3_ul_wdata(0),
    .s3_ul_wvalid(0),
    .s3_ul_wready(),

    // UL Write channel 0
    .m0_ul_waddr(m0_ul_waddr),
    .m0_ul_wdata(m0_ul_wdata),
    .m0_ul_wvalid(m0_ul_wvalid),
    .m0_ul_wready(m0_ul_wready),

    // UL Write channel 1
    .m1_ul_waddr(m1_ul_waddr),
    .m1_ul_wdata(m1_ul_wdata),
    .m1_ul_wvalid(m1_ul_wvalid),
    .m1_ul_wready(m1_ul_wready),

    // UL Write channel 2
    .m2_ul_waddr(m2_ul_waddr),
    .m2_ul_wdata(m2_ul_wdata),
    .m2_ul_wvalid(m2_ul_wvalid),
    .m2_ul_wready(m2_ul_wready),

    // UL Write channel 3
    .m3_ul_waddr(m3_ul_waddr),
    .m3_ul_wdata(m3_ul_wdata),
    .m3_ul_wvalid(m3_ul_wvalid),
    .m3_ul_wready(m3_ul_wready)
);

`include "xtrxll_regs.vh"


////////////////////////////////////////////////////////////////////////////////
// RD bus
wire [31:0] axis_rd_spi_rfic_data;
wire        axis_rd_spi_rfic_valid;
wire        axis_rd_spi_rfic_ready;

wire [31:0] axis_rd_uartrx_data;
wire        axis_rd_uartrx_valid;
wire        axis_rd_uartrx_ready;

wire [31:0] axis_rd_rxdma_stat_data;
wire        axis_rd_rxdma_stat_valid;
wire        axis_rd_rxdma_stat_ready;

wire [31:0] axis_rd_txdma_stat_data;
wire        axis_rd_txdma_stat_valid;
wire        axis_rd_txdma_stat_ready;

wire [31:0] axis_rd_i2c_data;
wire        axis_rd_i2c_valid;
wire        axis_rd_i2c_ready;

wire [31:0] axis_rd_onepps_data;
wire        axis_rd_onepps_valid;
wire        axis_rd_onepps_ready;

wire [31:0] axis_rd_sim_stat_data;
wire        axis_rd_sim_stat_valid;
wire        axis_rd_sim_stat_ready;

wire [31:0] axis_rd_sim_rdata;
wire        axis_rd_sim_rvalid;
wire        axis_rd_sim_rready;

wire [31:0] axis_rd_txmmcm_data;
wire        axis_rd_txmmcm_valid;
wire        axis_rd_txmmcm_ready;

wire [31:0] axis_rd_txdma_statm_data;
wire        axis_rd_txdma_statm_valid;
wire        axis_rd_txdma_statm_ready;

wire [31:0] axis_rd_txdma_statts_data;
wire        axis_rd_txdma_statts_valid;
wire        axis_rd_txdma_statts_ready;

wire [31:0] axis_rd_interrupts_data;
wire        axis_rd_interrupts_valid;
wire        axis_rd_interrupts_ready;

wire [31:0] axis_rd_tc_stat_tdata;
wire        axis_rd_tc_stat_tvalid;
wire        axis_rd_tc_stat_tready;

wire [31:0] axis_rd_rxdma_statts_data;
wire        axis_rd_rxdma_statts_valid;
wire        axis_rd_rxdma_statts_ready;

wire [31:0] axis_rd_mcu_debug_data;
wire        axis_rd_mcu_debug_valid;
wire        axis_rd_mcu_debug_ready;

wire [31:0] axis_rd_mcu_stat_data;
wire        axis_rd_mcu_stat_valid;
wire        axis_rd_mcu_stat_ready;


wire [31:0] axis_rd_qspi_rb_data;
wire        axis_rd_qspi_rb_valid;
wire        axis_rd_qspi_rb_ready;

wire [31:0] axis_rd_qspi_stat_data;
wire        axis_rd_qspi_stat_valid;
wire        axis_rd_qspi_stat_ready;

wire [31:0] axis_rd_mem_rb_data;
wire        axis_rd_mem_rb_valid;
wire        axis_rd_mem_rb_ready;

wire [31:0] axis_rd_txdma_stat_cpl_data;
wire        axis_rd_txdma_stat_cpl_valid;
wire        axis_rd_txdma_stat_cpl_ready;

wire [31:0] axis_rd_ref_osc_data;
wire        axis_rd_ref_osc_valid;
wire        axis_rd_ref_osc_ready;

wire [31:0] axis_rd_rxiq_miss_data;
wire        axis_rd_rxiq_miss_valid;
wire        axis_rd_rxiq_miss_ready;

wire [31:0] axis_rd_rxiq_odd_data;
wire        axis_rd_rxiq_odd_valid;
wire        axis_rd_rxiq_odd_ready;

wire [31:0] axis_rd_usb_rb_data;
wire        axis_rd_usb_rb_valid;
wire        axis_rd_usb_rb_ready;

wire [31:0] axis_rd_rxiq_period_data;
wire        axis_rd_rxiq_period_valid;
wire        axis_rd_rxiq_period_ready;

wire [31:0] axis_rd_hwcfg_data;
wire        axis_rd_hwcfg_valid;
wire        axis_rd_hwcfg_ready;

wire [31:0] axis_rd_gpio_in_data;
wire        axis_rd_gpio_in_valid;
wire        axis_rd_gpio_in_ready;

wire [31:0] axis_rd_gtime_sec_data;
wire        axis_rd_gtime_sec_valid;
wire        axis_rd_gtime_sec_ready;

wire [31:0] axis_rd_gtime_frac_data;
wire        axis_rd_gtime_frac_valid;
wire        axis_rd_gtime_frac_ready;

wire [31:0] axis_rd_gtime_off_data;
wire        axis_rd_gtime_off_valid;
wire        axis_rd_gtime_off_ready;

wire [31:0] axis_rd_usb_debug_data;
wire        axis_rd_usb_debug_valid;
wire        axis_rd_usb_debug_ready;

wire [31:0] axis_rd_gpio_spi_data;
wire        axis_rd_gpio_spi_valid;
wire        axis_rd_gpio_spi_ready;


localparam GP_RD_BITS = 5;
localparam GP_RD_SIZE = (1 << GP_RD_BITS);

wire [32*GP_RD_SIZE - 1:0] axis_port_rd_data;
wire [GP_RD_SIZE - 1:0]    axis_port_rd_valid;
wire [GP_RD_SIZE - 1:0]    axis_port_rd_ready;

wire [GP_RD_BITS - 1:0]    axis_port_rd_addr;
wire                       axis_port_rd_addr_valid;

assign axis_port_rd_data[32*GP_PORT_RD_SPI_LMS7_0 + 31 :32*GP_PORT_RD_SPI_LMS7_0]    = axis_rd_spi_rfic_data;
assign axis_port_rd_data[32*GP_PORT_RD_INTERRUPTS + 31 :32*GP_PORT_RD_INTERRUPTS]    = axis_rd_interrupts_data;
assign axis_port_rd_data[32*GP_PORT_RD_ONEPPS + 31     :32*GP_PORT_RD_ONEPPS]        = axis_rd_onepps_data;
assign axis_port_rd_data[32*GP_PORT_RD_TMP102 + 31     :32*GP_PORT_RD_TMP102]        = axis_rd_i2c_data;

assign axis_port_rd_data[32*GP_PORT_RD_UART_RX + 31    :32*GP_PORT_RD_UART_RX]       = axis_rd_uartrx_data;
assign axis_port_rd_data[32*GP_PORT_RD_SIM_RX + 31     :32*GP_PORT_RD_SIM_RX]        = axis_rd_sim_rdata;
assign axis_port_rd_data[32*GP_PORT_RD_SIM_STAT + 31   :32*GP_PORT_RD_SIM_STAT]      = axis_rd_sim_stat_data;
assign axis_port_rd_data[32*GP_PORT_RD_MCU_STAT + 31   :32*GP_PORT_RD_MCU_STAT]      = axis_rd_mcu_stat_data;

assign axis_port_rd_data[32*GP_PORT_RD_TXDMA_STAT + 31 :32*GP_PORT_RD_TXDMA_STAT]    = axis_rd_txdma_stat_data;
assign axis_port_rd_data[32*GP_PORT_RD_TXDMA_STATM + 31:32*GP_PORT_RD_TXDMA_STATM]   = axis_rd_txdma_statm_data;
assign axis_port_rd_data[32*GP_PORT_RD_TXDMA_STATTS+ 31:32*GP_PORT_RD_TXDMA_STATTS]  = axis_rd_txdma_statts_data;
assign axis_port_rd_data[32*GP_PORT_RD_TXDMA_ST_CPL+ 31:32*GP_PORT_RD_TXDMA_ST_CPL]  = axis_rd_txdma_stat_cpl_data;

assign axis_port_rd_data[32*GP_PORT_RD_RXDMA_STAT + 31 :32*GP_PORT_RD_RXDMA_STAT]    = axis_rd_rxdma_stat_data;
assign axis_port_rd_data[32*GP_PORT_RD_RXDMA_STATTS+ 31:32*GP_PORT_RD_RXDMA_STATTS]  = axis_rd_rxdma_statts_data;
assign axis_port_rd_data[32*GP_PORT_RD_TXMMCM + 31     :32*GP_PORT_RD_TXMMCM]        = axis_rd_txmmcm_data;
assign axis_port_rd_data[32*GP_PORT_RD_TCMDSTAT + 31   :32*GP_PORT_RD_TCMDSTAT]      = axis_rd_tc_stat_tdata;

assign axis_port_rd_data[32*GP_PORT_RD_QSPI_RB+ 31     :32*GP_PORT_RD_QSPI_RB]       = axis_rd_qspi_rb_data;
assign axis_port_rd_data[32*GP_PORT_RD_QSPI_STAT+ 31   :32*GP_PORT_RD_QSPI_STAT]     = axis_rd_qspi_stat_data;
assign axis_port_rd_data[32*GP_PORT_RD_MEM_RB+ 31      :32*GP_PORT_RD_MEM_RB]        = axis_rd_mem_rb_data;
assign axis_port_rd_data[32*GP_PORT_RD_MCU_DEBUG + 31  :32*GP_PORT_RD_MCU_DEBUG]     = axis_rd_mcu_debug_data;

assign axis_port_rd_data[32*GP_PORT_RD_REF_OSC + 31    :32*GP_PORT_RD_REF_OSC]       = axis_rd_ref_osc_data;
assign axis_port_rd_data[32*GP_PORT_RD_RXIQ_MISS + 31  :32*GP_PORT_RD_RXIQ_MISS]     = axis_rd_rxiq_miss_data;
assign axis_port_rd_data[32*GP_PORT_RD_RXIQ_ODD + 31   :32*GP_PORT_RD_RXIQ_ODD]      = axis_rd_rxiq_odd_data;
assign axis_port_rd_data[32*GP_PORT_RD_GPIO_SPI + 31   :32*GP_PORT_RD_GPIO_SPI]      = axis_rd_gpio_spi_data;

assign axis_port_rd_data[32*GP_PORT_RD_USB_RB + 31     :32*GP_PORT_RD_USB_RB]        = axis_rd_usb_rb_data;
assign axis_port_rd_data[32*GP_PORT_RD_RXIQ_PERIOD + 31:32*GP_PORT_RD_RXIQ_PERIOD]   = axis_rd_rxiq_period_data;
assign axis_port_rd_data[32*GP_PORT_RD_HWCFG + 31      :32*GP_PORT_RD_HWCFG]         = axis_rd_hwcfg_data;
assign axis_port_rd_data[32*GP_PORT_RD_GPIO_IN + 31    :32*GP_PORT_RD_GPIO_IN]       = axis_rd_gpio_in_data;

assign axis_port_rd_data[32*GP_PORT_RD_GTIME_SEC + 31  :32*GP_PORT_RD_GTIME_SEC]     = axis_rd_gtime_sec_data;
assign axis_port_rd_data[32*GP_PORT_RD_GTIME_FRAC + 31 :32*GP_PORT_RD_GTIME_FRAC]    = axis_rd_gtime_frac_data;
assign axis_port_rd_data[32*GP_PORT_RD_GTIME_OFF + 31  :32*GP_PORT_RD_GTIME_OFF]     = axis_rd_gtime_off_data;
assign axis_port_rd_data[32*GP_PORT_RD_USB_DEBUG + 31  :32*GP_PORT_RD_USB_DEBUG]     = axis_rd_usb_debug_data;


assign axis_port_rd_valid[GP_PORT_RD_SPI_LMS7_0] = axis_rd_spi_rfic_valid;
assign axis_port_rd_valid[GP_PORT_RD_INTERRUPTS] = axis_rd_interrupts_valid;
assign axis_port_rd_valid[GP_PORT_RD_ONEPPS]     = axis_rd_onepps_valid;
assign axis_port_rd_valid[GP_PORT_RD_TMP102]     = axis_rd_i2c_valid;

assign axis_port_rd_valid[GP_PORT_RD_UART_RX]    = axis_rd_uartrx_valid;
assign axis_port_rd_valid[GP_PORT_RD_SIM_RX]     = axis_rd_sim_rvalid;
assign axis_port_rd_valid[GP_PORT_RD_SIM_STAT]   = axis_rd_sim_stat_valid;
assign axis_port_rd_valid[GP_PORT_RD_MCU_STAT]   = axis_rd_mcu_stat_valid;

assign axis_port_rd_valid[GP_PORT_RD_TXDMA_STAT]  = axis_rd_txdma_stat_valid;
assign axis_port_rd_valid[GP_PORT_RD_TXDMA_STATM] = axis_rd_txdma_statm_valid;
assign axis_port_rd_valid[GP_PORT_RD_TXDMA_STATTS]= axis_rd_txdma_statts_valid;
assign axis_port_rd_valid[GP_PORT_RD_TXDMA_ST_CPL]= axis_rd_txdma_stat_cpl_valid;

assign axis_port_rd_valid[GP_PORT_RD_RXDMA_STAT]  = axis_rd_rxdma_stat_valid;
assign axis_port_rd_valid[GP_PORT_RD_RXDMA_STATTS]= axis_rd_rxdma_statts_valid;
assign axis_port_rd_valid[GP_PORT_RD_TXMMCM]      = axis_rd_txmmcm_valid;
assign axis_port_rd_valid[GP_PORT_RD_TCMDSTAT]    = axis_rd_tc_stat_tvalid;

assign axis_port_rd_valid[GP_PORT_RD_QSPI_RB]     = axis_rd_qspi_rb_valid;
assign axis_port_rd_valid[GP_PORT_RD_QSPI_STAT]   = axis_rd_qspi_stat_valid;
assign axis_port_rd_valid[GP_PORT_RD_MEM_RB]      = axis_rd_mem_rb_valid;
assign axis_port_rd_valid[GP_PORT_RD_MCU_DEBUG]   = axis_rd_mcu_debug_valid;

assign axis_port_rd_valid[GP_PORT_RD_REF_OSC]     = axis_rd_ref_osc_valid;
assign axis_port_rd_valid[GP_PORT_RD_RXIQ_MISS]   = axis_rd_rxiq_miss_valid;
assign axis_port_rd_valid[GP_PORT_RD_RXIQ_ODD]    = axis_rd_rxiq_odd_valid;
assign axis_port_rd_valid[GP_PORT_RD_GPIO_SPI]    = axis_rd_gpio_spi_valid;

assign axis_port_rd_valid[GP_PORT_RD_USB_RB]      = axis_rd_usb_rb_valid;
assign axis_port_rd_valid[GP_PORT_RD_RXIQ_PERIOD] = axis_rd_rxiq_period_valid;
assign axis_port_rd_valid[GP_PORT_RD_HWCFG]       = axis_rd_hwcfg_valid;
assign axis_port_rd_valid[GP_PORT_RD_GPIO_IN]     = axis_rd_gpio_in_valid;

assign axis_port_rd_valid[GP_PORT_RD_GTIME_SEC]   = axis_rd_gtime_sec_valid;
assign axis_port_rd_valid[GP_PORT_RD_GTIME_FRAC]  = axis_rd_gtime_frac_valid;
assign axis_port_rd_valid[GP_PORT_RD_GTIME_OFF]   = axis_rd_gtime_off_valid;
assign axis_port_rd_valid[GP_PORT_RD_USB_DEBUG]   = axis_rd_usb_debug_valid;


assign axis_rd_spi_rfic_ready   = axis_port_rd_ready[GP_PORT_RD_SPI_LMS7_0];
assign axis_rd_interrupts_ready = axis_port_rd_ready[GP_PORT_RD_INTERRUPTS];
assign axis_rd_onepps_ready     = axis_port_rd_ready[GP_PORT_RD_ONEPPS];
assign axis_rd_i2c_ready        = axis_port_rd_ready[GP_PORT_RD_TMP102];

assign axis_rd_uartrx_ready     = axis_port_rd_ready[GP_PORT_RD_UART_RX];
assign axis_rd_sim_rready       = axis_port_rd_ready[GP_PORT_RD_SIM_RX];
assign axis_rd_sim_stat_ready   = axis_port_rd_ready[GP_PORT_RD_SIM_STAT];
assign axis_rd_mcu_stat_ready   = axis_port_rd_ready[GP_PORT_RD_MCU_STAT];

assign axis_rd_txdma_stat_ready = axis_port_rd_ready[GP_PORT_RD_TXDMA_STAT];
assign axis_rd_txdma_statm_ready = axis_port_rd_ready[GP_PORT_RD_TXDMA_STATM];
assign axis_rd_txdma_statts_ready= axis_port_rd_ready[GP_PORT_RD_TXDMA_STATTS];
assign axis_rd_txdma_stat_cpl_ready= axis_port_rd_ready[GP_PORT_RD_TXDMA_ST_CPL];

assign axis_rd_rxdma_stat_ready  = axis_port_rd_ready[GP_PORT_RD_RXDMA_STAT];
assign axis_rd_rxdma_statts_ready= axis_port_rd_ready[GP_PORT_RD_RXDMA_STATTS];
assign axis_rd_txmmcm_ready      = axis_port_rd_ready[GP_PORT_RD_TXMMCM];
assign axis_rd_tc_stat_tready    = axis_port_rd_ready[GP_PORT_RD_TCMDSTAT];

assign axis_rd_qspi_rb_ready     = axis_port_rd_ready[GP_PORT_RD_QSPI_RB];
assign axis_rd_qspi_stat_ready   = axis_port_rd_ready[GP_PORT_RD_QSPI_STAT];
assign axis_rd_mem_rb_ready      = axis_port_rd_ready[GP_PORT_RD_MEM_RB];
assign axis_rd_mcu_debug_ready   = axis_port_rd_ready[GP_PORT_RD_MCU_DEBUG];

assign axis_rd_ref_osc_ready     = axis_port_rd_ready[GP_PORT_RD_REF_OSC];
assign axis_rd_rxiq_miss_ready   = axis_port_rd_ready[GP_PORT_RD_RXIQ_MISS];
assign axis_rd_rxiq_odd_ready    = axis_port_rd_ready[GP_PORT_RD_RXIQ_ODD];
assign axis_rd_gpio_spi_ready    = axis_port_rd_ready[GP_PORT_RD_GPIO_SPI];

assign axis_rd_usb_rb_ready      = axis_port_rd_ready[GP_PORT_RD_USB_RB];
assign axis_rd_rxiq_period_ready = axis_port_rd_ready[GP_PORT_RD_RXIQ_PERIOD];
assign axis_rd_hwcfg_ready       = axis_port_rd_ready[GP_PORT_RD_HWCFG];
assign axis_rd_gpio_in_ready     = axis_port_rd_ready[GP_PORT_RD_GPIO_IN];

assign axis_rd_gtime_sec_ready   = axis_port_rd_ready[GP_PORT_RD_GTIME_SEC];
assign axis_rd_gtime_frac_ready  = axis_port_rd_ready[GP_PORT_RD_GTIME_FRAC];
assign axis_rd_gtime_off_ready   = axis_port_rd_ready[GP_PORT_RD_GTIME_OFF];
assign axis_rd_usb_debug_ready   = axis_port_rd_ready[GP_PORT_RD_USB_DEBUG];


assign axis_rd_hwcfg_data = hwcfg;
assign axis_rd_hwcfg_valid = 1'b1;

// UL RB Read address channel
wire [UL_BUS_LEN-2:0]  rb_ul_araddr;
wire                   rb_ul_arvalid;
wire                   rb_ul_arready;

// UL RB Read data channel signals
wire[31:0]  rb_ul_rdata;
wire        rb_ul_rvalid;
wire        rb_ul_rready;

// UL MEM Read address channel
wire [UL_BUS_LEN-2:0]  mem_ul_araddr;
wire                   mem_ul_arvalid;
wire                   mem_ul_arready;

// UL MEM  Read data channel signals
wire[31:0]  mem_ul_rdata;
wire        mem_ul_rvalid;
wire        mem_ul_rready;

ul_read_demux_axis #(.NBITS(UL_BUS_LEN)) bus_demux (
    // UL clocks
    .s_ul_clk(clk),
    .s_ul_aresetn(~rst),

    // UL Read address channel 0
    .s_ul_araddr(s_ul_araddr),
    .s_ul_arvalid(s_ul_arvalid),
    .s_ul_arready(s_ul_arready),
    // UL Write data channel 0 signals
    .s_ul_rdata(s_ul_rdata),
    .s_ul_rvalid(s_ul_rvalid),
    .s_ul_rready(s_ul_rready),

    // mem port
    // UL Read address channel 0
    .m0_ul_araddr(rb_ul_araddr),
    .m0_ul_arvalid(rb_ul_arvalid),
    .m0_ul_arready(rb_ul_arready),
    // UL Write data channel 0 signals
    .m0_ul_rdata(rb_ul_rdata),
    .m0_ul_rvalid(rb_ul_rvalid),
    .m0_ul_rready(rb_ul_rready),

    // mem port
    // UL Read address channel 0
    .m1_ul_araddr(mem_ul_araddr),
    .m1_ul_arvalid(mem_ul_arvalid),
    .m1_ul_arready(mem_ul_arready),
    // UL Write data channel 0 signals
    .m1_ul_rdata(mem_ul_rdata),
    .m1_ul_rvalid(mem_ul_rvalid),
    .m1_ul_rready(mem_ul_rready)
);


ul_read_axis #(
    .DATA_WIDTH(32),
    .NBITS(GP_RD_BITS)
) ul_read_axis (
    // UL clocks
    .s_ul_clk(clk),
    .s_ul_aresetn(~rst),

    // UL Read address channel
    .s_ul_araddr(rb_ul_araddr[GP_RD_BITS - 1:0]),
    .s_ul_arvalid(rb_ul_arvalid),
    .s_ul_arready(rb_ul_arready),

    // UL Write data channel signals
    .s_ul_rdata(rb_ul_rdata),
    .s_ul_rvalid(rb_ul_rvalid),
    .s_ul_rready(rb_ul_rready),

    // read port
    .axis_port_ready(axis_port_rd_ready),
    .axis_port_valid(axis_port_rd_valid),
    .axis_port_data(axis_port_rd_data),

    .axis_port_addr(axis_port_rd_addr),
    .axis_port_addr_valid(axis_port_rd_addr_valid)
);

////////////////////////////////////////////////////////////////////////////////
// WR registers

localparam GP_BITS = 5;
localparam GP_SIZE = (1 << GP_BITS);

wire [31:0]         gp_out;
wire [GP_SIZE-1:0]  gp_strobe;
wire [GP_SIZE-1:0]  gp_in_ready;

ul_go_base #(
    .ADDR_WIDTH(GP_BITS)
) ul_go_base(

    // UL Write channel
    .s_ul_waddr(m0_ul_waddr[GP_BITS-1:0]),
    .s_ul_wdata(m0_ul_wdata),
    .s_ul_wvalid(m0_ul_wvalid),
    .s_ul_wready(m0_ul_wready),

    // GPIO
    .gp_out(gp_out),
    .gp_out_strobe(gp_strobe),
    .gp_in_ready(gp_in_ready)
);

wire axis_wr_spi_rfic_valid     = gp_strobe[GP_PORT_WR_SPI_LMS7_0];
wire axis_wr_rf_switches_valid  = gp_strobe[GP_PORT_WR_RF_SWITCHES] && ~gp_out[8];
wire axis_wr_dac_spi_valid      = gp_strobe[GP_PORT_WR_DAC_SPI];
wire axis_wr_uarttx_valid       = gp_strobe[GP_PORT_WR_UART_TX];
wire axis_wr_i2c_tx_valid       = gp_strobe[GP_PORT_WR_TMP102];
wire axis_wr_simtx_valid        = gp_strobe[GP_PORT_WR_SIM_TX];
wire axis_wr_simctrl_valid      = gp_strobe[GP_PORT_WR_SIM_CTRL];
wire axis_wr_lms_ctrl_valid     = gp_strobe[GP_PORT_WR_LMS_CTRL];
wire axis_wr_rxdma_confirm_valid= gp_strobe[GP_PORT_WR_RXDMA_CNFRM];
wire axis_wr_rxtxdma_valid      = gp_strobe[GP_PORT_WR_RXTXDMA];
wire axis_wr_txmmcm_valid       = gp_strobe[GP_PORT_WR_TXMMCM];
wire axis_wr_int_pcie_valid     = gp_strobe[GP_PORT_WR_INT_PCIE];
wire axis_wr_txdma_cnf_len_valid= gp_strobe[GP_PORT_WR_TXDMA_CNF_L];
wire axis_wr_txdma_cnf_tm_valid = gp_strobe[GP_PORT_WR_TXDMA_CNF_T];
wire axis_wr_tcmd_d_valid       = gp_strobe[GP_PORT_WR_TCMD_D];
wire axis_wr_tcmd_t_valid       = gp_strobe[GP_PORT_WR_TCMD_T];

wire axis_wr_qspi_excmd_valid   = gp_strobe[GP_PORT_WR_QSPI_EXCMD];
wire axis_wr_qspi_cmd_valid     = gp_strobe[GP_PORT_WR_QSPI_CMD];
wire axis_wr_mem_ctrl_valid     = gp_strobe[GP_PORT_WR_MEM_CTRL];
wire axis_wr_usb_ctrl_valid     = gp_strobe[GP_PORT_WR_USB_CTRL];
wire axis_wr_fifo_ctrl_valid    = gp_strobe[GP_PORT_WR_USB_FIFO_CTRL];
wire axis_wr_fifo_ptrs_valid    = gp_strobe[GP_PORT_WR_USB_FIFO_PTRS];
wire axis_wr_fe_cmd_valid       = gp_strobe[GP_PORT_WR_FE_CMD];
wire axis_wr_pps_cmd_valid      = gp_strobe[GP_PORT_WR_PPS_CMD];
wire axis_wr_gpio_func_valid    = gp_strobe[GP_PORT_WR_GPIO_FUNC];
wire axis_wr_gpio_dir_valid     = gp_strobe[GP_PORT_WR_GPIO_DIR];
wire axis_wr_gpio_out_valid     = gp_strobe[GP_PORT_WR_GPIO_OUT];
wire axis_wr_gpio_cs_valid      = gp_strobe[GP_PORT_WR_GPIO_CS];
wire axis_wr_globcmdr0_valid    = gp_strobe[GP_PORT_WR_GLOBCMDR0];
wire axis_wr_globcmdr1_valid    = gp_strobe[GP_PORT_WR_GLOBCMDR1];
wire axis_wr_gpio_spi_valid     = gp_strobe[GP_PORT_WR_GPIO_SPI];

wire axis_wr_spi_rfic_ready;
wire axis_wr_rf_switches_ready;
wire axis_wr_dac_spi_ready;
wire axis_wr_uarttx_ready;
wire axis_wr_i2c_tx_ready;
wire axis_wr_simtx_ready;
wire axis_wr_simctrl_ready;
wire axis_wr_lms_ctrl_ready;
wire axis_wr_rxdma_confirm_ready;
wire axis_wr_rxtxdma_ready;
wire axis_wr_txmmcm_ready;
wire axis_wr_int_pcie_ready;
wire axis_wr_txdma_cnf_len_ready;
wire axis_wr_txdma_cnf_tm_ready;
wire axis_wr_tcmd_d_ready;
wire axis_wr_tcmd_t_ready;

wire axis_wr_qspi_excmd_ready;
wire axis_wr_qspi_cmd_ready;
wire axis_wr_mem_ctrl_ready;
wire axis_wr_usb_ctrl_ready;
wire axis_wr_fifo_ctrl_ready;
wire axis_wr_fifo_ptrs_ready;
wire axis_wr_fe_cmd_ready;
wire axis_wr_pps_cmd_ready;
wire axis_wr_gpio_func_ready;
wire axis_wr_gpio_dir_ready;
wire axis_wr_gpio_out_ready;
wire axis_wr_gpio_cs_ready;
wire axis_wr_globcmdr0_ready;
wire axis_wr_globcmdr1_ready;
wire axis_wr_gpio_spi_ready;

assign gp_in_ready[GP_PORT_WR_SPI_LMS7_0]    = axis_wr_spi_rfic_ready;
assign gp_in_ready[GP_PORT_WR_RF_SWITCHES]   = axis_wr_rf_switches_ready;
assign gp_in_ready[GP_PORT_WR_DAC_SPI]       = axis_wr_dac_spi_ready;
assign gp_in_ready[GP_PORT_WR_UART_TX]       = axis_wr_uarttx_ready;
assign gp_in_ready[GP_PORT_WR_TMP102]        = axis_wr_i2c_tx_ready;
assign gp_in_ready[GP_PORT_WR_SIM_TX]        = axis_wr_simtx_ready;
assign gp_in_ready[GP_PORT_WR_SIM_CTRL]      = axis_wr_simctrl_ready;
assign gp_in_ready[GP_PORT_WR_LMS_CTRL]      = axis_wr_lms_ctrl_ready;
assign gp_in_ready[GP_PORT_WR_RXDMA_CNFRM]   = axis_wr_rxdma_confirm_ready;
assign gp_in_ready[GP_PORT_WR_RXTXDMA]       = axis_wr_rxtxdma_ready;
assign gp_in_ready[GP_PORT_WR_TXMMCM]        = axis_wr_txmmcm_ready;
assign gp_in_ready[GP_PORT_WR_INT_PCIE]      = axis_wr_int_pcie_ready;
assign gp_in_ready[GP_PORT_WR_TXDMA_CNF_L]   = axis_wr_txdma_cnf_len_ready;
assign gp_in_ready[GP_PORT_WR_TXDMA_CNF_T]   = axis_wr_txdma_cnf_tm_ready;
assign gp_in_ready[GP_PORT_WR_TCMD_D]        = axis_wr_tcmd_d_ready;
assign gp_in_ready[GP_PORT_WR_TCMD_T]        = axis_wr_tcmd_t_ready;

assign gp_in_ready[GP_PORT_WR_QSPI_EXCMD]    = axis_wr_qspi_excmd_ready;
assign gp_in_ready[GP_PORT_WR_QSPI_CMD]      = axis_wr_qspi_cmd_ready;
assign gp_in_ready[GP_PORT_WR_MEM_CTRL]      = axis_wr_mem_ctrl_ready;
assign gp_in_ready[GP_PORT_WR_USB_CTRL]      = axis_wr_usb_ctrl_ready;
assign gp_in_ready[GP_PORT_WR_USB_FIFO_CTRL] = axis_wr_fifo_ctrl_ready;
assign gp_in_ready[GP_PORT_WR_USB_FIFO_PTRS] = axis_wr_fifo_ptrs_ready;
assign gp_in_ready[GP_PORT_WR_FE_CMD]        = axis_wr_fe_cmd_ready;
assign gp_in_ready[GP_PORT_WR_PPS_CMD]       = axis_wr_pps_cmd_ready;
assign gp_in_ready[GP_PORT_WR_GPIO_FUNC]     = axis_wr_gpio_func_ready;
assign gp_in_ready[GP_PORT_WR_GPIO_DIR]      = axis_wr_gpio_dir_ready;
assign gp_in_ready[GP_PORT_WR_GPIO_OUT]      = axis_wr_gpio_out_ready;
assign gp_in_ready[GP_PORT_WR_GPIO_CS]       = axis_wr_gpio_cs_ready;
assign gp_in_ready[GP_PORT_WR_GLOBCMDR0]     = axis_wr_globcmdr0_ready;
assign gp_in_ready[GP_PORT_WR_GLOBCMDR1]     = axis_wr_globcmdr1_ready;
assign gp_in_ready[GP_PORT_WR_GPIO_SPI]      = axis_wr_gpio_spi_ready;

assign gp_in_ready[GP_SIZE-1:GP_PORT_WR_GPIO_SPI+1] = ~0;

////////////////////////////////////////////////////////////////////////////////
//    BUFFER MEM
wire [15:2] qspimem_addr;
wire        qspimem_valid;
wire        qspimem_wr;
wire [31:0] qspimem_out_data;
wire        qspimem_ready;

wire [31:0] qspimem_in_data;
wire        qspimem_in_valid;

wire [5:0]  mem_ul_waddr = m1_ul_waddr[5:0];
wire [31:0] mem_ul_wdata = m1_ul_wdata;
wire        mem_ul_wvalid = m1_ul_wvalid;
wire        mem_ul_wready;
assign m1_ul_wready = mem_ul_wready;

wire [31:0] mem_ul_rdata_p;
wire        mem_ul_rvalid_p;
wire        mem_ul_rready_p;

qspi_mem_buf qmem(
  .clk(clk),
  .rst(rst),

  // UL Write
  .mem_ul_waddr(mem_ul_waddr),
  .mem_ul_wdata(mem_ul_wdata),
  .mem_ul_wvalid(mem_ul_wvalid),
  .mem_ul_wready(mem_ul_wready),

  .mem_ul_araddr(mem_ul_araddr[5:0]),
  .mem_ul_arvalid(mem_ul_arvalid),
  .mem_ul_arready(mem_ul_arready),

  .mem_ul_rdata(mem_ul_rdata_p),
  .mem_ul_rvalid(mem_ul_rvalid_p),
  .mem_ul_rready(mem_ul_rready_p),

  // QSPI PORT
  .qspimem_addr(qspimem_addr[7:2]),
  .qspimem_valid(qspimem_valid),
  .qspimem_wr(qspimem_wr),
  .qspimem_out_data(qspimem_out_data),
  .qspimem_ready(qspimem_ready),
  .qspimem_in_data(qspimem_in_data),
  .qspimem_in_valid(qspimem_in_valid)
);

axis_fifo32 #(.DEEP_BITS(4)) rbfifo(
  .clk(clk),
  .axisrst(rst),

  .axis_rx_tdata(mem_ul_rdata_p),
  .axis_rx_tvalid(mem_ul_rvalid_p),
  .axis_rx_tready(mem_ul_rready_p),

  .axis_tx_tdata(mem_ul_rdata),
  .axis_tx_tvalid(mem_ul_rvalid),
  .axis_tx_tready(mem_ul_rready),

  .fifo_used(),
  .fifo_empty()
);

////////////////////////////////////////////////////////////////////////////////
// Interrupts

wire [INT_COUNT-1:0] int_valid;
wire [INT_COUNT-1:0] int_ready;

wire onepps_interrupt_valid;
wire onepps_interrupt_ready      = int_ready[INT_1PPS];
wire dmatx_interrupt_valid;
wire dmatx_interrupt_ready       = int_ready[INT_DMA_TX];
wire dmarx_interrupt_valid;
wire dmarx_interrupt_ready       = int_ready[INT_DMA_RX];
wire rfic_spi_interrupt_valid;
wire rfic_spi_interrupt_ready    = int_ready[INT_RFIC0_SPI];
wire gps_uart_tx_interrupt_valid;
wire gps_uart_tx_interrupt_ready = int_ready[INT_GPS_UART_TX];
wire gps_uart_rx_interrupt_valid;
wire gps_uart_rx_interrupt_ready = int_ready[INT_GPS_UART_RX];
wire sim_uart_tx_interrupt_valid;
wire sim_uart_tx_interrupt_ready = int_ready[INT_SIM_UART_TX];
wire sim_uart_rx_interrupt_valid;
wire sim_uart_rx_interrupt_ready = int_ready[INT_SIM_UART_RX];
wire tmp_interrupt_valid;
wire tmp_interrupt_ready         = int_ready[INT_I2C];
wire newcmd_int_valid;
wire newcmd_int_ready            = int_ready[INT_NCMD];
wire dmarx_interrupt_ovf_valid;
wire dmarx_interrupt_ovf_ready   = int_ready[INT_DMA_RX_OVF];


assign int_valid[INT_1PPS]         = onepps_interrupt_valid;
assign int_valid[INT_DMA_TX]       = dmatx_interrupt_valid;
assign int_valid[INT_DMA_RX]       = dmarx_interrupt_valid;
assign int_valid[INT_RFIC0_SPI]    = rfic_spi_interrupt_valid;
assign int_valid[INT_GPS_UART_TX]  = gps_uart_tx_interrupt_valid;
assign int_valid[INT_GPS_UART_RX]  = gps_uart_rx_interrupt_valid;
assign int_valid[INT_SIM_UART_TX]  = sim_uart_tx_interrupt_valid;
assign int_valid[INT_SIM_UART_RX]  = sim_uart_rx_interrupt_valid;
assign int_valid[INT_I2C]          = tmp_interrupt_valid;
assign int_valid[INT_NCMD]         = newcmd_int_valid;
assign int_valid[INT_DMA_RX_OVF]   = dmarx_interrupt_ovf_valid;

wire axis_wr_interrupts_valid = axis_wr_int_pcie_valid & gp_out[INT_PCIE_I_FLAG];
wire axis_wr_interrupts_ready;

wire [INT_COUNT-1:0] axis_wr_interrupts_data = gp_out[INT_COUNT-1:0];

int_router #(
    //.LOW_OP(INT_COUNT_L)
    .COUNT(INT_COUNT)
) int_router (
    .clk(clk),
    .reset(rst),

    // PCI-e interface
    .interrupt_msi_enabled(cfg_interrupt_msienable),
    .interrupt_rdy(cfg_interrupt_rdy),
    .interrupt(cfg_interrupt),
    .interrupt_assert(cfg_interrupt_assert),
    .interrupt_num(cfg_interrupt_di),

    .legacy_interrupt_disabled(legacy_interrupt_disabled),
    .interrupt_mmenable(cfg_interrupt_mmenable),
    .cap_interrupt_msgnum(cfg_pciecap_interrupt_msgnum),
    .cap_interrupt_stat(cfg_interrupt_stat),

    // User Interrupt status
    .int_stat_ready(axis_rd_interrupts_ready),
    .int_stat_valid(axis_rd_interrupts_valid),
    .int_stat_data(axis_rd_interrupts_data),

    // User Interrupt control
    .int_ctrl_ready(axis_wr_interrupts_ready),
    .int_ctrl_valid(axis_wr_interrupts_valid),
    .int_ctrl_data(axis_wr_interrupts_data),

    .int_valid(int_valid),
    .int_ready(int_ready)
);


////////////////////////////////////////////////////////////////////////////////
// GPIO SPI

wire gpio_spi_mosi;
wire gpio_spi_miso;
wire gpio_spi_sck;
wire gpio_spi_sen;

wire gpio_spi_interrupt_valid;
wire gpio_spi_interrupt_ready = 1'b1;

axis_spi #(
    .FIXED_DIV(32),
    .WR_ONLY(0)
) spi_gpio (
    .axis_clk(clk),
    .axis_resetn(~rst),

    // UL Write channel
    .axis_wdata(gp_out),
    .axis_wvalid(axis_wr_gpio_spi_valid),
    .axis_wready(axis_wr_gpio_spi_ready),

    .axis_rdata(axis_rd_gpio_spi_data),
    .axis_rvalid(axis_rd_gpio_spi_valid),
    .axis_rready(axis_rd_gpio_spi_ready),

    // SPI master
    .spi_mosi(gpio_spi_mosi),
    .spi_miso(gpio_spi_miso),
    .spi_sclk(gpio_spi_sck),
    .spi_sen(gpio_spi_sen),

    .spi_interrupt_valid(gpio_spi_interrupt_valid),
    .spi_interrupt_ready(gpio_spi_interrupt_ready)
);


///////////////////////////////////////////////////////////////////////////////
// XTRX GPIO with ALT functions
localparam GPIO_WIDTH = 14;

wire alt1_gpio1_pps_i;
wire alt1_gpio2_pps_iso_o;

wire [GPIO_WIDTH-1:0] alt0_se_gpio_oe = 14'b00_1111_0111_0110;
wire [GPIO_WIDTH-1:0] alt0_se_gpio_out = {
  1'b0, gpio12_alt1_stat,
  alt1_gpio2_pps_iso_o, gpio_spi_sck, gpio_spi_sen, gpio_spi_mosi,
  1'b0, gpio7_alt1_trouble, gpio6_alt1_pci_rstn, gpio5_alt1_usr_rstn,
  1'b0, 1'b0, alt1_gpio2_pps_iso_o, 1'b0
};
wire [GPIO_WIDTH-1:0] alt0_se_gpio_in;
assign alt1_gpio1_pps_i = alt0_se_gpio_in[0];
assign gpio_spi_miso    = alt0_se_gpio_in[9];

wire [GPIO_WIDTH-1:0] alt1_se_gpio_oe = 14'b0;
wire [GPIO_WIDTH-1:0] alt1_se_gpio_out = { 1'b0, gpio12_alt2_rx, 12'b0 } ;
wire [GPIO_WIDTH-1:0] alt1_se_gpio_in;

wire [GPIO_WIDTH-1:0] alt2_se_gpio_oe = 14'b0;
wire [GPIO_WIDTH-1:0] alt2_se_gpio_out = { 1'b0, gpio12_alt3_tx, 12'b0 } ;
wire [GPIO_WIDTH-1:0] alt2_se_gpio_in;

assign axis_rd_gpio_in_data[31:GPIO_WIDTH] = 0;

xtrx_gpio_ctrl #(
    .GPIO_WIDTH(GPIO_WIDTH),
    .GPIO_DEF_FUNCTIONS(28'b00_01__00_00_00_00__00_01_01_01__00_00_00_00)
) gpios (
    .clk(clk),
    .rst(rst),

    // GPIO configuration regusters
    .gpio_func_ready(axis_wr_gpio_func_ready),
    .gpio_func_valid(axis_wr_gpio_func_valid),
    .gpio_func_data(gp_out[GPIO_WIDTH*2-1:0]),

    .gpio_dir_ready(axis_wr_gpio_dir_ready),
    .gpio_dir_valid(axis_wr_gpio_dir_valid),
    .gpio_dir_data(gp_out[GPIO_WIDTH-1:0]),

    .gpio_out_ready(axis_wr_gpio_out_ready),
    .gpio_out_valid(axis_wr_gpio_out_valid),
    .gpio_out_data(gp_out[GPIO_WIDTH-1:0]),

    .gpio_cs_ready(axis_wr_gpio_cs_ready),
    .gpio_cs_valid(axis_wr_gpio_cs_valid),
    .gpio_cs_data(gp_out[GPIO_WIDTH*2-1:0]),

    // User Interrupt control
    .gpio_in_ready(axis_rd_gpio_in_ready),
    .gpio_in_valid(axis_rd_gpio_in_valid),
    .gpio_in_data(axis_rd_gpio_in_data[GPIO_WIDTH-1:0]),

    .se_gpio_oe(gpio_se_gpio_oe),
    .se_gpio_out(gpio_se_gpio_out),
    .se_gpio_in(gpio_se_gpio_in),

    // Alt function for specific GPIO(s)
    .alt0_se_gpio_oe(alt0_se_gpio_oe),
    .alt0_se_gpio_out(alt0_se_gpio_out),
    .alt0_se_gpio_in(alt0_se_gpio_in),

    .alt1_se_gpio_oe(alt1_se_gpio_oe),
    .alt1_se_gpio_out(alt1_se_gpio_out),
    .alt1_se_gpio_in(alt1_se_gpio_in),

    .alt2_se_gpio_oe(alt2_se_gpio_oe),
    .alt2_se_gpio_out(alt2_se_gpio_out),
    .alt2_se_gpio_in(alt2_se_gpio_in)
);
///////////////////////////////////////////////////////////////////////////////

// RFIC SPI
axis_spi #(
    .FIXED_DIV( (UL_BUS_SPEED + LMS7_SPI_SPEED - 1) / LMS7_SPI_SPEED )
) spi_rfic (
    .axis_clk(clk),
    .axis_resetn(~rst),

    // UL Write channel
    .axis_wdata(gp_out),
    .axis_wvalid(axis_wr_spi_rfic_valid),
    .axis_wready(axis_wr_spi_rfic_ready),

    .axis_rdata(axis_rd_spi_rfic_data),
    .axis_rvalid(axis_rd_spi_rfic_valid),
    .axis_rready(axis_rd_spi_rfic_ready),

    // SPI master
    .spi_mosi(rfic_mosi),
    .spi_miso(rfic_miso),
    .spi_sclk(rfic_sck),
    .spi_sen(rfic_sen),

    .spi_interrupt_valid(rfic_spi_interrupt_valid),
    .spi_interrupt_ready(rfic_spi_interrupt_ready)
);

assign axis_wr_lms_ctrl_ready = 1'b1;

// RFIC GPIO and helper wires
reg [15:0]             rfic_gpio_r;
reg [11:0]             rfic_ddr_ctrl_r;

assign rfic_gpio = rfic_gpio_r;
assign rfic_ddr_ctrl = rfic_ddr_ctrl_r;

always @(posedge clk) begin
  if (rst) begin
    rfic_gpio_r     <= 0;
    rfic_ddr_ctrl_r <= 4'b1111;

  end else if (axis_wr_lms_ctrl_ready && axis_wr_lms_ctrl_valid) begin
    if (~gp_out[16]) begin
      rfic_gpio_r     <= gp_out[15:0];
    end else begin
      rfic_ddr_ctrl_r <= gp_out[17+11-1:17];
    end
  end
end

// RF Switches
reg [1:0]  rx_switch_reg;
reg        tx_switch_reg;
assign tx_switch = tx_switch_reg;
assign rx_switch = rx_switch_reg;

assign axis_wr_rf_switches_ready = 1'b1;
always @(posedge clk) begin
  if (rst) begin
    rx_switch_reg <= 2'b00;
    tx_switch_reg <= 1'b0;
  end else if (axis_wr_rf_switches_ready && axis_wr_rf_switches_valid) begin
    rx_switch_reg  <= gp_out[1:0];
    tx_switch_reg  <= gp_out[2];
  end
end


wire [7:0] axis_uarttx_data  = gp_out[7:0];
wire [4:0] uart_tx_fifo_used;
wire       uart_tx_fifo_empty;
wire [15:0] axis_rd_uartrx_data_proxy;

assign axis_rd_uartrx_data[15:0]  = axis_rd_uartrx_data_proxy;
assign axis_rd_uartrx_data[UART_FIFOTX_USED_OFF+UART_FIFOTX_USED_BITS-1:UART_FIFOTX_USED_OFF] = uart_tx_fifo_used;
assign axis_rd_uartrx_data[UART_FIFOTX_EMPTY] = uart_tx_fifo_empty;
assign axis_rd_uartrx_data[31:UART_FIFOTX_EMPTY+1] = 0;

generate
if (NO_UART != 0) begin
  assign axis_rd_uartrx_data_proxy = 16'h8000;
  assign uart_tx_fifo_used = 0;
  assign uart_tx_fifo_empty = 1;

  assign uart_txd = 1'b1;

  assign gps_uart_rx_interrupt_valid = 1'b0;
  assign gps_uart_tx_interrupt_valid = 1'b0;

  assign axis_wr_uarttx_ready = 1'b1;
  assign axis_rd_uartrx_valid = 1'b1;

end else begin
  // UART RX for GPS
  ul_uart_rx #(
    .UART_SPEED(GPS_UART_SPEED),
    .BUS_SPEED(UL_BUS_SPEED)
  ) ul_uart_rx (
    .reset(rst),
    .axis_clk(clk),

    .rxd(uart_rxd),

    .axis_rdata(axis_rd_uartrx_data_proxy),
    .axis_rvalid(axis_rd_uartrx_valid),
    .axis_rready(axis_rd_uartrx_ready),

    .int_ready(gps_uart_rx_interrupt_ready),
    .int_valid(gps_uart_rx_interrupt_valid)
  );

  // UART RX for GPS
  ul_uart_tx #(
    .UART_SPEED(GPS_UART_SPEED),
    .BUS_SPEED(UL_BUS_SPEED)
  ) ul_uart_tx(
    .reset(rst),
    .axis_clk(clk),

    .txd(uart_txd),

    .axis_data(axis_uarttx_data),
    .axis_valid(axis_wr_uarttx_valid),
    .axis_ready(axis_wr_uarttx_ready),

    .fifo_used(uart_tx_fifo_used),
    .fifo_empty(uart_tx_fifo_empty),

    .int_ready(gps_uart_tx_interrupt_ready),
    .int_valid(gps_uart_tx_interrupt_valid)
  );
  end
endgenerate


// DUAL I2C BUS
generate
if (NO_TEMP != 0) begin
  assign axis_rd_i2c_data[31:0] = 0;
  assign axis_wr_i2c_tx_ready = 1'b1;
  assign axis_rd_i2c_valid = 1'b1;
  assign tmp_interrupt_valid = 0;

  assign sda1_out_eo = 1'b1;
  assign sda1_out_eo = 1'b1;

  assign sda2_out_eo = 1'b1;
  assign sda2_out_eo = 1'b1;
end else begin
  ul_i2c_dme  #(
    .I2C_SPEED(TMP102_I2C_SPEED),
    .BUS_SPEED(UL_BUS_SPEED)
  ) ul_i2c_dme (
    .reset(rst),
    .clk(clk),

    .dev_lut(xtrx_i2c_lut),

    .sda1_in(sda1_in),
    .sda1_out_eo(sda1_out_eo),
    .scl1_out_eo(scl1_out_eo),

    .sda2_in(sda2_in),
    .sda2_out_eo(sda2_out_eo),
    .scl2_out_eo(scl2_out_eo),

    .axis_cmdreg_data(gp_out),
    .axis_cmdreg_valid(axis_wr_i2c_tx_valid),
    .axis_cmdreg_ready(axis_wr_i2c_tx_ready),

    .axis_rbdata_data(axis_rd_i2c_data),
    .axis_rbdata_valid(axis_rd_i2c_valid),
    .axis_rbdata_ready(axis_rd_i2c_ready),

    .int_ready(tmp_interrupt_ready),
    .int_valid(tmp_interrupt_valid)
  );
  end
endgenerate

clk_estimator estimator(
  .rst(rst),
  .clk(clk),

  .meas_clk(osc_clk),

  .cntr_ready(axis_rd_ref_osc_ready),
  .cntr_valid(axis_rd_ref_osc_valid),
  .cntr_data(axis_rd_ref_osc_data)
);

// GPS
wire [TIMED_SEC_BITS+TIMED_FRAC_BITS-1:0] axis_global_ppstime;

assign axis_rd_gtime_sec_valid = 1'b1;
assign axis_rd_gtime_frac_valid = 1'b1;

generate
if (NO_PPS != 0) begin
  assign axis_rd_onepps_data    = 0;
  assign axis_rd_onepps_valid   = 1'b1;

  assign onepps_interrupt_valid = 0;

  assign axis_rd_gtime_sec_data = 0;
  assign axis_rd_gtime_frac_data = 0;

  assign axis_rd_gtime_off_data = 0;
  assign axis_rd_gtime_off_valid = 1'b1;

  assign axis_wr_pps_cmd_ready = 1'b1;
  assign alt1_gpio2_pps_iso_o = 1'b0;
end else begin
  onepps_ctrl onepps_ctrl (
    .osc_clk(osc_clk),
    .gps_onepps(onepps),
    .ext_onepps(alt1_gpio1_pps_i),
    .iso_pps(alt1_gpio2_pps_iso_o),

    .reset(rst),
    .axis_clk(clk),

    .axis_rx_ready(axis_rd_onepps_ready),
    .axis_rx_valid(axis_rd_onepps_valid),
    .axis_rx_data(axis_rd_onepps_data),

    .int_ready(onepps_interrupt_ready),
    .int_valid(onepps_interrupt_valid),

    .ppscfg_ready(axis_wr_pps_cmd_ready),
    .ppscfg_valid(axis_wr_pps_cmd_valid),
    .ppscfg_data(gp_out),

    .iso_pps_gps_data(axis_rd_gtime_off_data),
    .iso_pps_gps_valid(axis_rd_gtime_off_valid),

    .axis_ppstime(axis_global_ppstime)
  );

  assign axis_rd_gtime_sec_data  = axis_global_ppstime[TIMED_SEC_BITS+TIMED_FRAC_BITS-1:TIMED_FRAC_BITS];
  assign axis_rd_gtime_frac_data = axis_global_ppstime[TIMED_FRAC_BITS-1:0];
end
endgenerate

// SMARTCARD / UART
wire [31:0]axis_simtx_data  = gp_out[31:0];
wire [2:0] axis_simctrl_data  = gp_out[2:0];

generate
if (NO_SMART_CARD != 0) begin
  assign axis_rd_sim_rready = 1'b1;

  assign sim_uart_tx_interrupt_valid = 0;
  assign sim_uart_rx_interrupt_ready = 0;

  assign axis_rd_sim_rdata[31:UART_FIFOTX_EMPTY+1] = 0;
  assign axis_rd_sim_rdata[UART_FIFOTX_EMPTY]                                                 = 1'b1;
  assign axis_rd_sim_rdata[UART_FIFOTX_USED_OFF+UART_FIFOTX_USED_BITS-1:UART_FIFOTX_USED_OFF] = 0;

  assign axis_rd_sim_rdata[UART_FIFORX_EMPTY]  = 1'b1;
  assign axis_rd_sim_rdata[UART_FIFORX_PARERR] = 0;
  assign axis_rd_sim_rdata[13:8]  = 0;

  assign axis_rd_sim_stat_data = axis_rd_sim_rdata;

  assign axis_rd_sim_stat_valid  = 1'b1;
  assign axis_wr_simctrl_ready   = 1'b1;
  assign axis_rd_sim_rvalid      = 1'b1;

end else begin
ul_uart_smartcard #(
    .BUS_SPEED(UL_BUS_SPEED),
    .SIM_SPEED(SIM_SPEED)
) ul_uart_smartcard (
    .reset(rst),
    .axis_clk(clk),

    .rxd(sim_data_in),
    .txd_oen(sim_data_oen),

    .sim_clk(sim_clk_out),
    .sim_reset(sim_reset_out),
    .sim_stopn(sim_enable_out),
    .sim_mode33v(sim_mode_out),

    // Output data readback stream
    .axis_rdata(axis_rd_sim_rdata),
    .axis_rvalid(axis_rd_sim_rvalid),
    .axis_rready(axis_rd_sim_rready),

    // Input data for UART
    .axis_data(axis_simtx_data),
    .axis_valid(axis_wr_simtx_valid),
    .axis_ready(axis_wr_simtx_ready),

    // Input data for CFG & control
    .axis_cfg_data(axis_simctrl_data),
    .axis_cfg_valid(axis_wr_simctrl_valid),
    .axis_cfg_ready(axis_wr_simctrl_ready),

    .axis_stat_data(axis_rd_sim_stat_data),
    .axis_stat_valid(axis_rd_sim_stat_valid),
    .axis_stat_ready(axis_rd_sim_stat_ready),

    .int_tx_ready(sim_uart_tx_interrupt_ready),
    .int_tx_valid(sim_uart_tx_interrupt_valid),
    .int_rx_ready(sim_uart_rx_interrupt_ready),
    .int_rx_valid(sim_uart_rx_interrupt_valid)
);
end
endgenerate

// DRP
ul_drp_cfg #(
  .GPIO_RESET_P0(0),
  .GPIO_RESET_P1(0),
  .GPIO_RESET_P2(0),
  .GPIO_RESET_P3(0)
) drp_bridge (
    .reset(rst),
    .axis_clk(clk),

    .axis_out_data(axis_rd_txmmcm_data),
    .axis_out_valid(axis_rd_txmmcm_valid),
    .axis_out_ready(axis_rd_txmmcm_ready),

    .axis_in_data(gp_out),
    .axis_in_valid(axis_wr_txmmcm_valid),
    .axis_in_ready(axis_wr_txmmcm_ready),


    .drp_clk(drp_clk),

    // DRP port0
    .drp_di_0(drp_di_0),
    .drp_daddr_0(drp_daddr_0),
    .drp_den_0(drp_den_0),
    .drp_dwe_0(drp_dwe_0),
    .drp_do_0(drp_do_0),
    .drp_drdy_0(drp_drdy_0),

    .drp_gpio_out_0(drp_gpio_out_0),
    .drp_gpio_in_0(drp_gpio_in_0),

    // DRP port1
    .drp_di_1(drp_di_1),
    .drp_daddr_1(drp_daddr_1),
    .drp_den_1(drp_den_1),
    .drp_dwe_1(drp_dwe_1),
    .drp_do_1(drp_do_1),
    .drp_drdy_1(drp_drdy_1),

    .drp_gpio_out_1(drp_gpio_out_1),
    .drp_gpio_in_1(drp_gpio_in_1),

    // DRP port2
    .drp_di_2(drp_di_2),
    .drp_daddr_2(drp_daddr_2),
    .drp_den_2(drp_den_2),
    .drp_dwe_2(drp_dwe_2),
    .drp_do_2(drp_do_2),
    .drp_drdy_2(drp_drdy_2),

    .drp_gpio_out_2(drp_gpio_out_2),
    .drp_gpio_in_2(drp_gpio_in_2),

    // DRP port3
    .drp_di_3(drp_di_3),
    .drp_daddr_3(drp_daddr_3),
    .drp_den_3(drp_den_3),
    .drp_dwe_3(drp_dwe_3),
    .drp_do_3(drp_do_3),
    .drp_drdy_3(drp_drdy_3),

    .drp_gpio_out_3(drp_gpio_out_3),
    .drp_gpio_in_3(drp_gpio_in_3)
);


/////////////////////////////////////////////////////////////
// Timed commands

generate
if (NO_GTIME != 0) begin
  assign st_ul_waddr = 0;
  assign st_ul_wdata = 0;
  assign st_ul_wvalid = 1'b0;
  assign st_ul_wready = 1'b1;

  assign axis_wr_globcmdr0_ready = 1'b1;
  assign axis_wr_globcmdr1_ready = 1'b1;
end else begin
  // GTIMED
  g_timed_cmd globtimed(
    .clk(clk),
    .rst(rst),

    .gtime_sec(axis_global_ppstime[TIMED_SEC_BITS+TIMED_FRAC_BITS-1:TIMED_FRAC_BITS]),
    .gtime_ticks(axis_global_ppstime[TIMED_FRAC_BITS-1:0]),

    .g0_cmd_data(gp_out),
    .g0_cmd_valid(axis_wr_globcmdr0_valid),
    .g0_cmd_ready(axis_wr_globcmdr0_ready),

    .g1_cmd_data(gp_out),
    .g1_cmd_valid(axis_wr_globcmdr1_valid),
    .g1_cmd_ready(axis_wr_globcmdr1_ready),


    .m_ul_waddr(st_ul_waddr),
    .m_ul_wdata(st_ul_wdata),
    .m_ul_wvalid(st_ul_wvalid),
    .m_ul_wready(st_ul_wready)
  );
end
endgenerate

cmd_queue #(
    .TS_BITS(TS_BITS)
) tc_queue (
    .ts_clk(ts_clk),
    .ts_current(ts_current),

    // CMD clock
    .newcmd_clk(clk),
    .newcmd_reset(~rx_running),

    // CMD control
    .newcmd_ready(axis_wr_tcmd_t_ready),
    .newcmd_valid(axis_wr_tcmd_t_valid),
    .newcmd_data(gp_out[TS_BITS-1:0]),

    // CMD statistics
    .newcmd_stat_ready(axis_rd_tc_stat_tready),
    .newcmd_stat_valid(axis_rd_tc_stat_tvalid),
    .newcmd_stat_data(axis_rd_tc_stat_tdata),

    // Interrupt logic
    .newcmd_int_ready(newcmd_int_ready),
    .newcmd_int_valid(newcmd_int_valid),

    // TS clock
    .cmd_ready(ts_command_rxfrm_ready),
    .cmd_valid(ts_command_rxfrm_valid)
);


// QSPI Flash
wire flash_reset;
sync_reg #(.INIT(1), .ASYNC_RESET(1)) flash_sync_reset_reg(
    .clk(flash_cclk),
    .rst(rst),
    .in(rst),
    .out(flash_reset)
);

ul_qspi_mem_async #(.ASYNC_CLOCKS(FLASH_ASYNC_CLOCKS)) ul_qspi_mem_async(
    .clk(clk),
    .reset(rst),

    // qspi excmd
    .qspi_excmd_valid(axis_wr_qspi_excmd_valid),
    .qspi_excmd_data(gp_out),
    .qspi_excmd_ready(axis_wr_qspi_excmd_ready),

    // qspi cmd
    .qspi_cmd_valid(axis_wr_qspi_cmd_valid),
    .qspi_cmd_data(gp_out),
    .qspi_cmd_ready(axis_wr_qspi_cmd_ready),

    // qspi debug Rd
    .qspi_rd_valid(axis_rd_qspi_rb_valid),
    .qspi_rd_data(axis_rd_qspi_rb_data),
    .qspi_rd_ready(axis_rd_qspi_rb_ready),

    // qspi status
    .qspi_stat_valid(axis_rd_qspi_stat_valid),
    .qspi_stat_data(axis_rd_qspi_stat_data),
    .qspi_stat_ready(axis_rd_qspi_stat_ready),

    //////////////////////////////
    // Buffer memory interface
    .mem_addr(qspimem_addr),
    .mem_valid(qspimem_valid),
    .mem_wr(qspimem_wr),
    .mem_out_data(qspimem_out_data),
    .mem_ready(qspimem_ready),

    .mem_in_data(qspimem_in_data),
    .mem_in_valid(qspimem_in_valid),

    //////////////////////////////
    .qphy_clk(flash_cclk),
    .qphy_reset(flash_reset),

    .qphy_di(flash_din),
    .qphy_do(flash_dout),
    .qphy_dt(flash_ndrive),
    .qphy_dncs(flash_ncs) // Crystal select
);


assign axis_wr_tcmd_d_ready = 1'b1;

////////////////////////////////////////////////////////////////////////////////
// DAC spi
assign axis_wr_dac_spi_ready = 1'b1;

////////////////////////////////////////////////////////////////////////////////
// USB2 PHY + EP_WRAPPER

assign phy_nrst = 1'b0;
assign phy_do = 1'b0;
assign phy_doe = 1'b0;
// STP should be high in reset state
assign phy_stp = 1'b1;

// Dummy writes to USB core
assign axis_wr_usb_ctrl_ready = 1'b1;
assign axis_wr_fifo_ctrl_ready = 1'b1;
assign axis_wr_fifo_ptrs_ready = 1'b1;

assign axis_rd_usb_rb_valid = 1'b1;
assign axis_rd_usb_rb_data = 0;

assign axis_rd_usb_debug_valid = 1'b1;
assign axis_rd_usb_debug_data = 0;

////////////////////////////////////////////////////////////////////////////////
// MCU

assign axis_wr_mem_ctrl_ready = 1'b1;

assign axis_rd_mcu_debug_valid = 1'b1;
assign axis_rd_mcu_debug_data = 0;

assign axis_rd_mcu_stat_valid = 1'b1;
assign axis_rd_mcu_stat_data = 0;

assign axis_rd_mem_rb_valid = 1'b1;
assign axis_rd_mem_rb_data = 0;


////////////////////////////////////////////////////////////////////////////////
// DMA SUPPORT LOGIC

reg rx_ctrl_dntchk;
reg rx_ctrl_intovfsep;
wire axis_wr_pcie_cfg_ready = 1'b1;
wire axis_wr_pcie_cfg_valid = axis_wr_int_pcie_valid && gp_out[INT_PCIE_E_FLAG];

reg [2:0]   cfg_max_req_sz;
reg         cfg_max_payload_sz;
reg         cfg_pcie_alt_mode = 1'b0;

always @(posedge clk) begin
  if (rst) begin
    rx_ctrl_dntchk            <= 0;
    rx_ctrl_intovfsep         <= 0;

    cfg_pcie_alt_mode         <= 0;

  end else begin
    if (~cfg_pcie_alt_mode) begin
      cfg_max_payload_sz        <= cfg_max_payload_size[0];
      cfg_max_req_sz            <= cfg_max_read_req_size;
    end

    if (axis_wr_pcie_cfg_ready && axis_wr_pcie_cfg_valid) begin
      cfg_pcie_alt_mode         <= gp_out[INT_PCIE_E_OVRD];
      if (gp_out[INT_PCIE_E_OVRD]) begin
        cfg_max_payload_sz      <= gp_out[16];
        cfg_max_req_sz          <=  (gp_out[19:17] < 3'b100) ? gp_out[19:17] : 3'b101;
      end

      rx_ctrl_dntchk            <= gp_out[INT_PCIE_E_NO_RX_DMA_FLOW];
      rx_ctrl_intovfsep         <= gp_out[INT_PCIE_E_RX_SEP_OVF_INT];
    end
  end
end

assign axis_wr_int_pcie_ready = axis_wr_pcie_cfg_ready && axis_wr_interrupts_ready;


wire        axis_wr_rxdma_controlcomb_valid;
wire [9:0]  axis_wr_rxdma_controlcomb_data;
wire        axis_wr_rxdma_controlcomb_ready;

wire        axis_wr_txdma_controlcomb_valid;
wire [19:0] axis_wr_txdma_controlcomb_data;
wire        axis_wr_txdma_controlcomb_ready;

axis_atomic_fo #(.CHA_BITS(20), .CHB_BITS(10)) txrxb (
    .reset(rst),
    .s_ul_clk(clk),

    .s_axis_comb_tready(axis_wr_rxtxdma_ready),
    .s_axis_comb_tvalid(axis_wr_rxtxdma_valid),
    .s_axis_comb_tdata(gp_out[29:0]),
    .s_axis_comb_tuser({gp_out[GP_PORT_WR_RXTXDMA_RXV], gp_out[GP_PORT_WR_RXTXDMA_TXV]}),

    .m_axis_cha_tready(axis_wr_txdma_controlcomb_ready),
    .m_axis_cha_tvalid(axis_wr_txdma_controlcomb_valid),
    .m_axis_cha_tdata(axis_wr_txdma_controlcomb_data),

    .m_axis_chb_tready(axis_wr_rxdma_controlcomb_ready),
    .m_axis_chb_tvalid(axis_wr_rxdma_controlcomb_valid),
    .m_axis_chb_tdata(axis_wr_rxdma_controlcomb_data)
);

assign axis_rd_rxdma_statts_valid = 1'b1;
assign axis_rd_rxdma_statts_data = rxfeX_ts_current;

assign axis_rd_rxiq_miss_valid = 1'b1;
assign axis_rd_rxiq_odd_valid = 1'b1;
assign axis_rd_rxiq_period_valid = 1'b1;

assign axis_rd_rxiq_miss_data = rxfe0_phy_iq_miss;
assign axis_rd_rxiq_odd_data = rxfe0_phy_iq_odd;
assign axis_rd_rxiq_period_data = rxfe0_phy_iq_period;


assign rxfe0_cmd_data       = gp_out;
assign rxfe0_cmd_valid      = axis_wr_fe_cmd_valid;
assign axis_wr_fe_cmd_ready = rxfe0_cmd_ready;

dma_rx_sm  #(
   .BUFFER_SIZE_RX_BITS(BUFFER_SIZE_RX_BITS),
   .BUFFER_BURST_BITS(5)
) dma_rx_sm (
    .s_ul_clk(clk),
    .s_ul_aresetn(~rst),

    // UL Write channel
    .s_ul_waddr(m2_ul_waddr),  //1 KB space
    .s_ul_wdata(m2_ul_wdata),
    .s_ul_wvalid(m2_ul_wvalid),
    .s_ul_wready(m2_ul_wready),

    .axis_control_data(axis_wr_rxdma_controlcomb_data),
    .axis_control_valid(axis_wr_rxdma_controlcomb_valid),
    .axis_control_ready(axis_wr_rxdma_controlcomb_ready),

    .ctrl_dntchk(rx_ctrl_dntchk),
    .ctrl_intovfsep(rx_ctrl_intovfsep),

    // Buffer confirmation channel
    .axis_confirm_valid(axis_wr_rxdma_confirm_valid),
    .axis_confirm_ready(axis_wr_rxdma_confirm_ready),

    .axis_stat_data(axis_rd_rxdma_stat_data),
    .axis_stat_valid(axis_rd_rxdma_stat_valid),
    .axis_stat_ready(axis_rd_rxdma_stat_ready),

    .cfg_max_payload_sz(cfg_max_payload_sz),

    // Bus data move request
    .ul_lm_rvalid(ul_lm_rvalid),
    .ul_lm_rready(ul_lm_rready),
    .ul_lm_rlocaddr(ul_lm_rlocaddr),
    .ul_lm_rbusaddr(ul_lm_rbusaddr),
    .ul_lm_rlength(ul_lm_rlength),
    .ul_lm_rtag(ul_lm_rtag),

    // Bus data move confirmation
    .ul_lm_tvalid(ul_lm_tvalid),
    .ul_lm_tready(ul_lm_tready),
    .ul_lm_ttag(ul_lm_ttag),

    // Interrupt
    .int_ready(dmarx_interrupt_ready),
    .int_valid(dmarx_interrupt_valid),

    .intovf_ready(dmarx_interrupt_ovf_ready),
    .intovf_valid(dmarx_interrupt_ovf_valid),

    // Writer stats (for overrun detection)
    .writer_pos(rxfe0_bufpos),

    // DMA timmed control
    .dma_resume_cmd(rxfe0_resume),

    // RX Fronetend config
    .fe_decim_rate(rxfe0_ctrl[1:0]),
    .fe_fmt(rxfe0_ctrl[3:2]),
    .fe_siso_mode(rxfe0_ctrl[4]),
    .fe_enable(rxfe0_ctrl[5]),
    .fe_rst(rxfe0_ctrl[6]),
    .fe_stall(rxfe0_ctrl[7])
);

/////////////////////////////////////////////////////
// TX
assign axis_wr_txdma_cnf_len_ready = 1'b1;
reg [11:0]      tx_burst_samples;
always @(posedge clk) begin
  if (rst) begin
    tx_burst_samples <= 0;
  end else if (axis_wr_txdma_cnf_len_ready && axis_wr_txdma_cnf_len_valid) begin
    tx_burst_samples <= gp_out[11:0];
  end
end

dma_tx_sm #(
  .TS_BITS(TS_BITS),
  .LOW_ADDDR_BITS(BUFFER_SIZE_TX_BITS - 3)
) dma_tx_sm (
    .mclk(txfe0_mclk),
    .arst(txfe0_arst),
    .mode_siso(txfe0_mode_siso),
    .mode_repeat(txfe0_mode_repeat),
    .mode_interp(txfe0_mode_interp),
    .debug_fe_state(txfe0_debug_fe_state),
    .debug_rd_addr(txfe0_debug_rd_addr),

    .ts_rd_addr_inc(txfe0_ts_rd_addr_inc),
    .ts_rd_addr_late_samples(txfe0_ts_rd_addr_late_samples),

    .ts_rd_addr_processed_inc(txfe0_ts_rd_addr_processed_inc),
    .ts_rd_valid(txfe0_ts_rd_valid),   // Valid start time & No of samples
    .ts_rd_start(txfe0_ts_rd_start),
    .ts_rd_samples(txfe0_ts_rd_samples),
    .ts_current(txfe0_ts_current),

    .out_rd_rst(txfe0_out_rd_rst),
    .out_rd_clk(txfe0_out_rd_clk),
    .out_rd_addr(txfe0_out_rd_addr),

    // Maximum request size
    .cfg_max_req_sz(cfg_max_req_sz),

    // UL
    .s_ul_clk(clk),
    .s_ul_aresetn(~rst),

    // UL Write channel
    .s_ul_waddr(m3_ul_waddr),  //1 KB space
    .s_ul_wdata(m3_ul_wdata),
    .s_ul_wvalid(m3_ul_wvalid),
    .s_ul_wready(m3_ul_wready),

    .axis_control_data(axis_wr_txdma_controlcomb_data),
    .axis_control_valid(axis_wr_txdma_controlcomb_valid),
    .axis_control_ready(axis_wr_txdma_controlcomb_ready),

    // Burst Iface
    .axis_burst_data({ tx_burst_samples, gp_out }),
    .axis_burst_valid(axis_wr_txdma_cnf_tm_valid),
    .axis_burst_ready(axis_wr_txdma_cnf_tm_ready),

    // Request & notify
    .ul_ml_rvalid(ul_ml_rvalid),
    .ul_ml_rready(ul_ml_rready),
    .ul_ml_rlocaddr(ul_ml_rlocaddr),
    .ul_ml_rbusaddr(ul_ml_rbusaddr),
    .ul_ml_rlength(ul_ml_rlength),
    .ul_ml_rtag(ul_ml_rtag),

    .ul_ml_tvalid(ul_ml_tvalid),
    .ul_ml_tready(ul_ml_tready),
    .ul_ml_ttag(ul_ml_ttag),

    .axis_stat_data(axis_rd_txdma_stat_data),
    .axis_stat_valid(axis_rd_txdma_stat_valid),
    .axis_stat_ready(axis_rd_txdma_stat_ready),

    .axis_stat_m_data(axis_rd_txdma_statm_data),
    .axis_stat_m_valid(axis_rd_txdma_statm_valid),
    .axis_stat_m_ready(axis_rd_txdma_statm_ready),

    .axis_stat_ts_data(axis_rd_txdma_statts_data),
    .axis_stat_ts_valid(axis_rd_txdma_statts_valid),
    .axis_stat_ts_ready(axis_rd_txdma_statts_ready),

    .axis_stat_cpl_data(axis_rd_txdma_stat_cpl_data),
    .axis_stat_cpl_valid(axis_rd_txdma_stat_cpl_valid),
    .axis_stat_cpl_ready(axis_rd_txdma_stat_cpl_ready),

    .txdma_active(txdma_active),

    // Notification (LED)
    .tx_running(tx_running),

    .int_ready(dmatx_interrupt_ready),
    .int_valid(dmatx_interrupt_valid)
);



endmodule
