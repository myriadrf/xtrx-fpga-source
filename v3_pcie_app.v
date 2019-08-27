// Application module without Xilinx specific cores

module v3_pcie_app #(
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
  parameter FLASH_ASYNC_CLOCKS = 1,
  parameter PHY_DIAG_BITS    = 32,
  parameter TS_BITS          = 30,
  parameter FW_ID            = 0,
  parameter COMPAT_ID        = 8'b0
)(
  ////////////////////////////////////////////////////////
  // PCI express
  //
  input            user_clk,
  input            user_reset,
  input            user_lnk_up,

  input            mcu_bootp,

  // Tx
  input            s_axis_tx_tready,
  output  [63:0]   s_axis_tx_tdata,
  output  [7:0]    s_axis_tx_tkeep,
  output           s_axis_tx_tlast,
  output           s_axis_tx_tvalid,

  // Rx
  input  [63:0]    m_axis_rx_tdata,
  input  [7:0]     m_axis_rx_tkeep,
  input            m_axis_rx_tlast,
  input            m_axis_rx_tvalid,
  output           m_axis_rx_tready,
  input  [6:0]     pcie_rx_bar_hit,

  // PCIe extra
  input  [15:0]    pcie_cfg_completer_id,

  output           cfg_interrupt,
  output           cfg_interrupt_assert,
  output [7:0]     cfg_interrupt_di,
  output           cfg_interrupt_stat,
  output [4:0]     cfg_pciecap_interrupt_msgnum,
  input [2:0]      cfg_interrupt_mmenable,
  input            cfg_interrupt_rdy,
  input            cfg_interrupt_msienable,
  input            legacy_interrupt_disabled,

  // PCIe config
  input [2:0]      cfg_max_read_req_size,
  input            cfg_no_snoop_enable,
  input            cfg_ext_tag_enabled,
  input [2:0]      cfg_max_payload_size,
  input            cfg_relax_ord_enabled,


  // XTRX general ctrl
  output [15:0]   xtrx_ctrl_lines,
  input [31:0]    xtrx_i2c_lut,

  ////////////////////////////////////////////////////////
  // LMS7
  output          lms7_mosi,
  input           lms7_miso,
  output          lms7_sck,
  output          lms7_sen,

  // PortRX - input
  input                 lms7_rx_clk,
  input [11:0]          lms7_rx_ai,
  input [11:0]          lms7_rx_aq,
  input [11:0]          lms7_rx_bi,
  input [11:0]          lms7_rx_bq,
  input                 lms7_rx_valid,
  input [PHY_DIAG_BITS-1:0] lms7_rxiq_miss,
  input [PHY_DIAG_BITS-1:0] lms7_rxiq_odd,
  input [PHY_DIAG_BITS-1:0] lms7_rxiq_period,
  output                lms7_rx_enable,
  output                lms7_rx_delay_clk,
  output [3:0]          lms7_rx_delay_idx,
  output [4:0]          lms7_rx_delay,

  // PortTX - output
  input           lms7_tx_clk,
  output [11:0]   lms7_tx_ai,
  output [11:0]   lms7_tx_aq,
  output [11:0]   lms7_tx_bi,
  output [11:0]   lms7_tx_bq,
  output          lms7_tx_en,

  output          rx_running,
  output          tx_running,

  // LML Hardware phy config
  input [3:0]     lms7_lml1_phy_hwid,
  input [3:0]     lms7_lml2_phy_hwid,

  // RF Switches
  output          tx_switch,
  output [1:0]    rx_switch,

  // GPS
  input           uart_rxd,
  output          uart_txd,

  // I2C (TMP108/DAC/PWR)
  input           sda1_in,
  output          sda1_out_eo,
  output          scl1_out_eo,

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
  input  [3:0]  drp_gpio_in_3
);

localparam REQ_TAG_BITS = 5;

localparam TIMED_FRAC_BITS = 26;
localparam TIMED_SEC_BITS = 32;

wire        s_axis_tx_ul_tready;
wire [63:0] s_axis_tx_ul_tdata;
wire [7:0]  s_axis_tx_ul_tkeep;
wire        s_axis_tx_ul_tlast;
wire        s_axis_tx_ul_tvalid;

wire        s_axis_tx_rxdma_tready;
wire [63:0] s_axis_tx_rxdma_tdata;
wire [7:0]  s_axis_tx_rxdma_tkeep;
wire        s_axis_tx_rxdma_tlast;
wire        s_axis_tx_rxdma_tvalid;

wire        s_axis_tx_txdma_tready;
wire [63:0] s_axis_tx_txdma_tdata;
wire [7:0]  s_axis_tx_txdma_tkeep;
wire        s_axis_tx_txdma_tlast;
wire        s_axis_tx_txdma_tvalid;

axis_mux4 axis_mux4(
    .s_axis_clk(user_clk),
    .s_arstn(~user_reset),

    .m_axis_tready(s_axis_tx_tready),
    .m_axis_tdata(s_axis_tx_tdata),
    .m_axis_tkeep(s_axis_tx_tkeep),
    .m_axis_tlast(s_axis_tx_tlast),
    .m_axis_tvalid(s_axis_tx_tvalid),

    .s0_axis_tready(s_axis_tx_ul_tready),
    .s0_axis_tdata(s_axis_tx_ul_tdata),
    .s0_axis_tkeep(s_axis_tx_ul_tkeep),
    .s0_axis_tlast(s_axis_tx_ul_tlast),
    .s0_axis_tvalid(s_axis_tx_ul_tvalid),

    .s1_axis_tready(s_axis_tx_txdma_tready),
    .s1_axis_tdata(s_axis_tx_txdma_tdata),
    .s1_axis_tkeep(s_axis_tx_txdma_tkeep),
    .s1_axis_tlast(s_axis_tx_txdma_tlast),
    .s1_axis_tvalid(s_axis_tx_txdma_tvalid),

    .s2_axis_tready(s_axis_tx_rxdma_tready),
    .s2_axis_tdata(s_axis_tx_rxdma_tdata),
    .s2_axis_tkeep(s_axis_tx_rxdma_tkeep),
    .s2_axis_tlast(s_axis_tx_rxdma_tlast),
    .s2_axis_tvalid(s_axis_tx_rxdma_tvalid),

    .s3_axis_tready(),
    .s3_axis_tdata(0),
    .s3_axis_tkeep(0),
    .s3_axis_tlast(0),
    .s3_axis_tvalid(0)
);

wire m_axis_rx_tready_txdma;
wire m_axis_rx_tready_ul;

assign m_axis_rx_tready = (pcie_rx_bar_hit[0]) ? m_axis_rx_tready_ul : m_axis_rx_tready_txdma;

////////////////////////////////////////////////////////////////////////////////
// Block RAMs
localparam RAM_TX_ADDR_W = 17;
localparam RAM_RX_ADDR_W = 16;

localparam WIDTH_RX = 64;
wire                     fe_rxdma_ten;
wire [RAM_RX_ADDR_W-1:3] fe_rxdma_taddr;
wire [WIDTH_RX-1:0]      fe_rxdma_tdata_wr;

wire [7:0]               rxdma_bram_wbe = 0;
wire [WIDTH_RX-1:0]      rxdma_bram_data_wr = 0;
wire [WIDTH_RX-1:0]      rxdma_bram_data_rd;
wire [RAM_RX_ADDR_W-1:3] rxdma_bram_addr;
wire                     rxdma_bram_en;

// 64kB, direct map
blk_mem_gen_nrx fifo_mem_rx (
    .clka(user_clk),
    .rsta(user_reset),
    .ena(rxdma_bram_en),
    .wea(rxdma_bram_wbe),
    .addra(rxdma_bram_addr),
    .dina(rxdma_bram_data_wr),
    .douta(rxdma_bram_data_rd),

    .clkb(lms7_rx_clk),
    .rstb(1'b0),
    .enb(fe_rxdma_ten),
    .web(8'hff),
    .addrb(fe_rxdma_taddr),
    .dinb(fe_rxdma_tdata_wr),
    .doutb()
);

wire                     txdma_bram_en;
wire [7:0]               txdma_bram_wbe;
wire [63:0]              txdma_bram_data_wr;
wire [RAM_TX_ADDR_W-1:3] txdma_bram_addr;


localparam WIDTH_TX = 48;
wire [5:0]           txdma_bram_wbe_mapped;
wire [WIDTH_TX-1:0]  txdma_bram_data_wr_mapped;
wire [WIDTH_TX-1:0]  txdma_bram_data_rd_mapped;

wire txdma_bram_data_rd = {
  txdma_bram_data_rd_mapped[47:36], 4'b0000,
  txdma_bram_data_rd_mapped[35:24], 4'b0000,
  txdma_bram_data_rd_mapped[23:12], 4'b0000,
  txdma_bram_data_rd_mapped[11:0],  4'b0000
};
assign txdma_bram_data_wr_mapped = {
  txdma_bram_data_wr[63:52],
  txdma_bram_data_wr[47:36],
  txdma_bram_data_wr[31:20],
  txdma_bram_data_wr[15:4]
};

assign txdma_bram_wbe_mapped = {
  txdma_bram_wbe[7] | txdma_bram_wbe[6],
  txdma_bram_wbe[6] | txdma_bram_wbe[5],
  txdma_bram_wbe[5] | txdma_bram_wbe[4],

  txdma_bram_wbe[3] | txdma_bram_wbe[2],
  txdma_bram_wbe[2] | txdma_bram_wbe[1],
  txdma_bram_wbe[1] | txdma_bram_wbe[0]
};

wire                     fe_txdma_ten;
wire [RAM_TX_ADDR_W-1:3] fe_txdma_taddr;
wire [WIDTH_TX-1:0]      fe_txdma_tdata_rd;

// 96kB of RAM mapped to 128kB space, 8b -> 6b on the fly translation
blk_mem_gen_ntx fifo_mem_tx (
    .clka(user_clk),
    .rsta(user_reset),
    .ena(txdma_bram_en),
    .wea(txdma_bram_wbe_mapped),
    .addra(txdma_bram_addr),
    .dina(txdma_bram_data_wr_mapped),
    .douta(txdma_bram_data_rd_mapped),

    .clkb(lms7_tx_clk),
    .rstb(1'b0),
    .enb(fe_txdma_ten),
    .web(6'h00),
    .addrb(fe_txdma_taddr),
    .dinb(0),
    .doutb(fe_txdma_tdata_rd)
);

////////////////////////////////////////////////////////////////////////////////
// RX DMA FE CONTROL
//

wire [2:0]               rxfe0_bufpos;
wire                     rxfe0_resume;
wire [7:0]               rxfe0_ctrl;

wire [31:0]              rxfe0_cmd_data;
wire                     rxfe0_cmd_valid;
wire                     rxfe0_cmd_ready;

wire                     ts_command_rxfrm_ready;
wire                     ts_command_rxfrm_valid;

wire [TS_BITS-1:0]       ts_current;
wire [TS_BITS-1:0]       rxfeX_ts_current;

fe_rx_chain_brst #(
   .BUFFER_SIZE_BITS(RAM_RX_ADDR_W - 3),
   .TS_BITS(TS_BITS)
) fe_rx (
  // LMS7
  .rx_clk(lms7_rx_clk),
  .sdr_ai(lms7_rx_ai),
  .sdr_aq(lms7_rx_aq),
  .sdr_bi(lms7_rx_bi),
  .sdr_bq(lms7_rx_bq),
  .sdr_valid(lms7_rx_valid),
  .o_sdr_enable(lms7_rx_enable),

  // TS for timed commands
  .ts_current(ts_current),

  // TS
  .ts_command_valid(ts_command_rxfrm_valid),
  .ts_command_ready(ts_command_rxfrm_ready),

  .rx_running(rx_running),

  // FE CTRL
  .rxfe_ctrl_clk(user_clk),

  .rxfe_bufpos(rxfe0_bufpos),
  .rxfe_resume(rxfe0_resume),
  .rxfe_ctrl(rxfe0_ctrl),

  // RAM FIFO Interface
  .rxfe_rxdma_ten(fe_rxdma_ten),
  .rxfe_rxdma_taddr(fe_rxdma_taddr),
  .rxfe_rxdma_tdata_wr(fe_rxdma_tdata_wr),

  .rxfe_cmd_data(rxfe0_cmd_data),
  .rxfe_cmd_valid(rxfe0_cmd_valid),
  .rxfe_cmd_ready(rxfe0_cmd_ready),

  // Timestamp report in another clock domain
  .cc_ts_current(rxfeX_ts_current)
);

////////////////////////////////////////////////////////////////////////////////
// TX DMA FE CONTROL
//
wire                      txfe0_mclk = lms7_tx_clk;
wire                      txfe0_arst;
wire                      txfe0_mode_siso;
wire                      txfe0_mode_repeat;
wire [2:0]                txfe0_mode_interp;
wire [1:0]                txfe0_debug_fe_state;
wire [RAM_TX_ADDR_W - 3-1:0] txfe0_debug_rd_addr;

wire                      txfe0_ts_rd_addr_inc;
wire [TS_BITS-1:0]        txfe0_ts_rd_addr_late_samples;

wire                      txfe0_ts_rd_addr_processed_inc;
wire                      txfe0_ts_rd_valid;   // Valid start time & No of samples
wire [TS_BITS-1:0]        txfe0_ts_rd_start;
wire [RAM_TX_ADDR_W - 3-1:0] txfe0_ts_rd_samples;
wire [TS_BITS-1:0]        txfe0_ts_current;

wire                      txfe0_out_rd_clk;
wire                      txfe0_out_rd_rst;
wire [RAM_TX_ADDR_W - 3:4]   txfe0_out_rd_addr;

fe_tx_chain_brst #(
    .LOW_ADDDR_BITS(RAM_TX_ADDR_W - 3),
    .TS_BITS(TS_BITS)
) fe_tx (
    .mclk(lms7_tx_clk),
    .arst(txfe0_arst),
    .mode_siso(txfe0_mode_siso),
    .mode_repeat(txfe0_mode_repeat),
    .inter_rate(txfe0_mode_interp),

    // LMS7 if
    .out_sdr_ai(lms7_tx_ai),
    .out_sdr_aq(lms7_tx_aq),
    .out_sdr_bi(lms7_tx_bi),
    .out_sdr_bq(lms7_tx_bq),
    .out_strobe(),

    // Output overrun notification
    // TODO
    .debug_fe_state(txfe0_debug_fe_state),
    .debug_rd_addr(txfe0_debug_rd_addr),

    .ts_rd_addr_inc(txfe0_ts_rd_addr_inc),
    .ts_rd_addr_late_samples(txfe0_ts_rd_addr_late_samples),

    .ts_rd_addr_processed_inc(txfe0_ts_rd_addr_processed_inc),
    .ts_rd_valid(txfe0_ts_rd_valid),   // Valid start time & No of samples
    .ts_rd_start(txfe0_ts_rd_start),
    .ts_rd_samples(txfe0_ts_rd_samples),
    .ts_current(txfe0_ts_current),

    //FIFO RAM iface
    .fifo_rd_en(fe_txdma_ten),
    .fifo_rd_addr(fe_txdma_taddr),
    .fifo_rd_data(fe_txdma_tdata_rd),

    // Output current read addr (with 1 extra MSB)
    .out_rd_rst(txfe0_out_rd_rst),
    .out_rd_clk(txfe0_out_rd_clk),
    .out_rd_addr(txfe0_out_rd_addr)
);

////////////////////////////////////////////////////////////////////////////////
// PCIe TX Requester & parser
wire m_ram_tvalid;
assign txdma_bram_en  = m_ram_tvalid;
assign txdma_bram_wbe = {8{m_ram_tvalid}};

wire                           ul_ml_rvalid;
wire                           ul_ml_rready;
wire [RAM_TX_ADDR_W-1:3]       ul_ml_rlocaddr;
wire [31:3]                    ul_ml_rbusaddr;
wire [8:0]                     ul_ml_rlength;
wire [4:0]                     ul_ml_rtag;

wire                           ul_ml_tvalid;
wire                           ul_ml_tready;
wire [4:0]                     ul_ml_ttag;

wire txdma_active;

pcie_req_to_ram #(
    .LOW_ADDDR_BITS(RAM_TX_ADDR_W - 3)
) pcieram (
    .s_ul_clk(user_clk),
    .s_ul_aresetn(~user_reset),

    .txdma_active(txdma_active),

    .cfg_pcie_reqid(pcie_cfg_completer_id),

    // AXIs PCIe TX (completion)
    .s_axis_rx_tready(m_axis_rx_tready_txdma),
    .s_axis_rx_tdata(m_axis_rx_tdata),
    .s_axis_rx_tkeep(m_axis_rx_tkeep),
    .s_axis_rx_tlast(m_axis_rx_tlast),
    .s_axis_rx_tvalid(m_axis_rx_tvalid && ~pcie_rx_bar_hit[0]),

    // AXIs PCIe TX
    .m_axis_tx_tready(s_axis_tx_txdma_tready),
    .m_axis_tx_tdata(s_axis_tx_txdma_tdata),
    .m_axis_tx_tkeep(s_axis_tx_txdma_tkeep),
    .m_axis_tx_tlast(s_axis_tx_txdma_tlast),
    .m_axis_tx_tvalid(s_axis_tx_txdma_tvalid),

    // RAM interface
    .m_ram_tdata(txdma_bram_data_wr),
    .m_ram_taddr(txdma_bram_addr),
    .m_ram_tvalid(m_ram_tvalid),

    // Request & notify
    .ul_ml_rvalid(ul_ml_rvalid),
    .ul_ml_rready(ul_ml_rready),
    .ul_ml_rlocaddr(ul_ml_rlocaddr),
    .ul_ml_rbusaddr(ul_ml_rbusaddr),
    .ul_ml_rlength(ul_ml_rlength),
    .ul_ml_rtag(ul_ml_rtag),

    .ul_ml_tvalid(ul_ml_tvalid),
    .ul_ml_tready(ul_ml_tready),
    .ul_ml_ttag(ul_ml_ttag)
);

////////////////////////////////////////////////////////////////////////////////
// PCIe Data pusher
wire                           ul_lm_rvalid;
wire                           ul_lm_rready;
wire [RAM_RX_ADDR_W-1:3]       ul_lm_rlocaddr;
wire [31:3]                    ul_lm_rbusaddr;
wire [4:0]                     ul_lm_rlength;
wire [0:0]                     ul_lm_rtag;

wire                           ul_lm_tvalid;
wire                           ul_lm_tready;
wire [0:0]                     ul_lm_ttag;

pcie_ram_to_wr #(
    .BUFFER_SIZE_BITS(RAM_RX_ADDR_W)
) rx_wr(
    .s_ul_clk(user_clk),
    .s_ul_aresetn(~user_reset),

    .ul_lm_rvalid(ul_lm_rvalid),
    .ul_lm_rready(ul_lm_rready),
    .ul_lm_rlocaddr(ul_lm_rlocaddr),
    .ul_lm_rbusaddr(ul_lm_rbusaddr),
    .ul_lm_rlength(ul_lm_rlength),
    .ul_lm_rtag(ul_lm_rtag),

    .ul_lm_tvalid(ul_lm_tvalid),
    .ul_lm_tready(ul_lm_tready),
    .ul_lm_ttag(ul_lm_ttag),

    .cfg_pcie_attr(/*cfg_pcie_dma_rx_attr*/ 2'b00),
    .cfg_pcie_reqid(pcie_cfg_completer_id),

    // AXIs PCIe TX
    .m_axis_tx_tready(s_axis_tx_rxdma_tready),
    .m_axis_tx_tdata(s_axis_tx_rxdma_tdata),
    .m_axis_tx_tkeep(s_axis_tx_rxdma_tkeep),
    .m_axis_tx_tlast(s_axis_tx_rxdma_tlast),
    .m_axis_tx_tvalid(s_axis_tx_rxdma_tvalid),

    // RAM interface
    .bram_data_rd(rxdma_bram_data_rd),
    .bram_addr(rxdma_bram_addr),
    .bram_en(rxdma_bram_en)
);


/////////////////////////////////////
// PCIe master
wire [9:0]  s_ul_waddr;
wire [31:0] s_ul_wdata;
wire        s_ul_wvalid;
wire        s_ul_wready;

// UL Read address channel
wire [9:0]  s_ul_araddr;
wire        s_ul_arvalid;
wire        s_ul_arready;

// UL Read data channel signals
wire[31:0]  s_ul_rdata;
wire        s_ul_rvalid;
wire        s_ul_rready;


pcie_to_ul pcie_to_ul(
    .clk(user_clk),
    .rst_n(~user_reset),

    // Configuration
    .cfg_completer_id(pcie_cfg_completer_id),

    // ULs PCIe RX
    .m_axis_rx_tdata(m_axis_rx_tdata),
    .m_axis_rx_tkeep(m_axis_rx_tkeep),
    .m_axis_rx_tlast(m_axis_rx_tlast),
    .m_axis_rx_tvalid(m_axis_rx_tvalid && pcie_rx_bar_hit[0]),
    .m_axis_rx_tready(m_axis_rx_tready_ul),

    // ULs PCIe TX
    .s_axis_tx_tready(s_axis_tx_ul_tready),
    .s_axis_tx_tdata(s_axis_tx_ul_tdata),
    .s_axis_tx_tkeep(s_axis_tx_ul_tkeep),
    .s_axis_tx_tlast(s_axis_tx_ul_tlast),
    .s_axis_tx_tvalid(s_axis_tx_ul_tvalid),

    /////////////////////////////////////

    // UL Write channel
    .m_ul_waddr(s_ul_waddr),
    .m_ul_wdata(s_ul_wdata),
    .m_ul_wvalid(s_ul_wvalid),
    .m_ul_wready(s_ul_wready),

    // UL Read address channel
    .m_ul_araddr(s_ul_araddr),
    .m_ul_arvalid(s_ul_arvalid),
    .m_ul_arready(s_ul_arready),

    // UL Read data channel signals
    .m_ul_rdata(s_ul_rdata),
    .m_ul_rvalid(s_ul_rvalid),
    .m_ul_rready(s_ul_rready)
);

wire [11:0] rfic_ddr_ctrl;
assign lms7_rx_delay     = rfic_ddr_ctrl[8:4];
assign lms7_rx_delay_idx = rfic_ddr_ctrl[3:0];
assign lms7_rx_delay_clk = user_clk;

assign lms7_tx_en = tx_running;

wire [31:0] hwcfg = { FW_ID[15:0], COMPAT_ID[7:0], lms7_lml2_phy_hwid, lms7_lml1_phy_hwid };

localparam UL_BUS_LEN = 10;

xtrx_peripherals #(
  .UL_BUS_LEN(UL_BUS_LEN),
  .BUFFER_BUS_ADDRESS(32),
  .BUFFER_SIZE_RX_BITS(RAM_RX_ADDR_W),
  .BUFFER_SIZE_TX_BITS(RAM_TX_ADDR_W),
  .MEM_TAG(5),
  .TS_BITS(TS_BITS),
  .UL_BUS_SPEED(UL_BUS_SPEED),
  .GPS_UART_SPEED(GPS_UART_SPEED),
  .TMP102_I2C_SPEED(TMP102_I2C_SPEED),
  .SIM_SPEED(SIM_SPEED),
  .LMS7_SPI_SPEED(LMS7_SPI_SPEED),
  .NO_UART(NO_UART),
  .NO_SMART_CARD(NO_SMART_CARD),
  .NO_TEMP(NO_TEMP),
  .NO_PPS(NO_PPS),
  .NO_GTIME(NO_GTIME),
  .FLASH_ASYNC_CLOCKS(FLASH_ASYNC_CLOCKS)
) xtrx_peripherals (
  .clk(user_clk),
  .rst(user_reset),

  // UL Write channel
  .s_ul_waddr(s_ul_waddr),
  .s_ul_wdata(s_ul_wdata),
  .s_ul_wvalid(s_ul_wvalid),
  .s_ul_wready(s_ul_wready),

  // UL Read address channel
  .s_ul_araddr(s_ul_araddr),
  .s_ul_arvalid(s_ul_arvalid),
  .s_ul_arready(s_ul_arready),

  // UL Read data channel signals
  .s_ul_rdata(s_ul_rdata),
  .s_ul_rvalid(s_ul_rvalid),
  .s_ul_rready(s_ul_rready),

  // HWCFG DATA
  .hwcfg(hwcfg),
  .xtrx_i2c_lut(xtrx_i2c_lut),

  // PCIe Interrupts
  .cfg_interrupt(cfg_interrupt),
  .cfg_interrupt_assert(cfg_interrupt_assert),
  .cfg_interrupt_di(cfg_interrupt_di),
  .cfg_interrupt_stat(cfg_interrupt_stat),
  .cfg_pciecap_interrupt_msgnum(cfg_pciecap_interrupt_msgnum),
  .cfg_interrupt_mmenable(cfg_interrupt_mmenable),
  .cfg_interrupt_rdy(cfg_interrupt_rdy),
  .cfg_interrupt_msienable(cfg_interrupt_msienable),
  .legacy_interrupt_disabled(legacy_interrupt_disabled),
  .cfg_max_read_req_size(cfg_max_read_req_size),
  .cfg_max_payload_size(cfg_max_payload_size),

  //
  // RX FE Ctrl
  //
  .rxfe0_phy_iq_miss(lms7_rxiq_miss),
  .rxfe0_phy_iq_odd(lms7_rxiq_odd),
  .rxfe0_phy_iq_period(lms7_rxiq_period),

  .rxfe0_bufpos(rxfe0_bufpos),
  .rxfe0_resume(rxfe0_resume),
  .rxfe0_ctrl(rxfe0_ctrl),

  .rxfe0_cmd_data(rxfe0_cmd_data),
  .rxfe0_cmd_valid(rxfe0_cmd_valid),
  .rxfe0_cmd_ready(rxfe0_cmd_ready),

  .rxfeX_ts_current(rxfeX_ts_current),

  .ts_clk(lms7_rx_clk),
  .ts_current(ts_current),
  .ts_command_rxfrm_ready(ts_command_rxfrm_ready),
  .ts_command_rxfrm_valid(ts_command_rxfrm_valid),

  //
  // TX FE Ctl
  //
  .txfe0_mclk(lms7_tx_clk),
  .txfe0_arst(txfe0_arst),
  .txfe0_mode_siso(txfe0_mode_siso),
  .txfe0_mode_repeat(txfe0_mode_repeat),
  .txfe0_mode_interp(txfe0_mode_interp),
  .txfe0_debug_fe_state(txfe0_debug_fe_state),
  .txfe0_debug_rd_addr(txfe0_debug_rd_addr),

  .txfe0_ts_rd_addr_inc(txfe0_ts_rd_addr_inc),
  .txfe0_ts_rd_addr_late_samples(txfe0_ts_rd_addr_late_samples),

  .txfe0_ts_rd_addr_processed_inc(txfe0_ts_rd_addr_processed_inc),
  .txfe0_ts_rd_valid(txfe0_ts_rd_valid),   // Valid start time & No of samples
  .txfe0_ts_rd_start(txfe0_ts_rd_start),
  .txfe0_ts_rd_samples(txfe0_ts_rd_samples),
  .txfe0_ts_current(txfe0_ts_current),

  .txfe0_out_rd_rst(txfe0_out_rd_rst),
  .txfe0_out_rd_clk(txfe0_out_rd_clk),
  .txfe0_out_rd_addr(txfe0_out_rd_addr),

  .tx_running(tx_running),

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

  // Bus data move request
  .ul_ml_rvalid(ul_ml_rvalid),
  .ul_ml_rready(ul_ml_rready),
  .ul_ml_rlocaddr(ul_ml_rlocaddr),
  .ul_ml_rbusaddr(ul_ml_rbusaddr),
  .ul_ml_rlength(ul_ml_rlength),
  .ul_ml_rtag(ul_ml_rtag),
  // Bus data move confirmation
  .ul_ml_tvalid(ul_ml_tvalid),
  .ul_ml_tready(ul_ml_tready),
  .ul_ml_ttag(ul_ml_ttag),

  //
  // RFIC CTRL & SPI
  .rfic_gpio(xtrx_ctrl_lines),
  .rfic_ddr_ctrl(rfic_ddr_ctrl),
  .rfic_mosi(lms7_mosi),
  .rfic_miso(lms7_miso),
  .rfic_sck(lms7_sck),
  .rfic_sen(lms7_sen),

  //
  // RF Switches
  .tx_switch(tx_switch),
  .rx_switch(rx_switch),

  // GPS
  .uart_rxd(uart_rxd),
  .uart_txd(uart_txd),

  .sda1_in(sda1_in),
  .sda1_out_eo(sda1_out_eo),
  .scl1_out_eo(scl1_out_eo),

  .sda2_in(sda2_in),
  .sda2_out_eo(sda2_out_eo),
  .scl2_out_eo(scl2_out_eo),

  // 1PPS
  .osc_clk(osc_clk),
  .onepps(onepps),

  // SIM
  .sim_mode_out(sim_mode_out),
  .sim_enable_out(sim_enable_out),
  .sim_clk_out(sim_clk_out),
  .sim_reset_out(sim_reset_out),

  .sim_data_in(sim_data_in),
  .sim_data_oen(sim_data_oen),

  // QSPI FLASH
  .flash_dout(flash_dout),
  .flash_din(flash_din),
  .flash_ndrive(flash_ndrive),
  .flash_ncs(flash_ncs),
  .flash_cclk(flash_cclk),

  // USB2 PHY
  .phy_clk(phy_clk),

  .phy_nrst(phy_nrst),
  .phy_do(phy_do),
  .phy_di(phy_di),
  .phy_doe(phy_doe),

  .phy_dir(phy_dir),
  .phy_nxt(phy_nxt),
  .phy_stp(phy_stp),

  // GPIO
  .gpio_se_gpio_oe(gpio_se_gpio_oe),
  .gpio_se_gpio_out(gpio_se_gpio_out),
  .gpio_se_gpio_in(gpio_se_gpio_in),
  .gpio5_alt1_usr_rstn(gpio5_alt1_usr_rstn),
  .gpio6_alt1_pci_rstn(gpio6_alt1_pci_rstn),
  .gpio7_alt1_trouble(gpio7_alt1_trouble),
  .gpio12_alt1_stat(gpio12_alt1_stat),
  .gpio12_alt2_rx(gpio12_alt2_rx),
  .gpio12_alt3_tx(gpio12_alt3_tx),

  // DRPs if
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
  .drp_gpio_in_3(drp_gpio_in_3),

  .rx_running(rx_running),
  .txdma_active(txdma_active)
);

endmodule
