module xlnx_lms7_lml_phy #(
  parameter IN_MODE = 1,   // 0 - off, 1 - slow, 2 - fast
  parameter OUT_MODE = 2,  // 0 - off, 1 - slow, 2 - fast
  parameter USE_IDELAY = 1,
  parameter STAT_DIAG_BITS = 32,
  parameter IN_FIFO = 1,
  parameter IRX_IQSEL_PHASE = 1
)(
// LMS7 LML port
  output        lms_i_txnrx,
  inout         lms_io_iqsel,
  input         lms_o_mclk,
  output        lms_i_fclk,
  inout [11:0]  lms_io_diq,

// PHY configuration port
  input         cfg_mmcm_drp_dclk,
  input [15:0]  cfg_mmcm_drp_di,
  input [6:0]   cfg_mmcm_drp_daddr,
  input         cfg_mmcm_drp_den,
  input         cfg_mmcm_drp_dwe,
  output [15:0] cfg_mmcm_drp_do,
  output        cfg_mmcm_drp_drdy,
  input  [3:0]  cfg_mmcm_drp_gpio_out,
  output [3:0]  cfg_mmcm_drp_gpio_in,

  input         cfg_rx_idelay_clk,
  input [4:0]   cfg_rx_idelay_data,
  input [3:0]   cfg_rx_idelay_addr,

  input         cfg_port_tx,
  input         cfg_port_enable,
  input         cfg_port_rxfclk_dis,
  input         cfg_port_rxterm_dis,

  output [2:0]  hwcfg_port,

// PHY statistics
  output [STAT_DIAG_BITS-1:0] stat_rx_frame_err,
  output [STAT_DIAG_BITS-1:0] stat_rx_corr,

// DATA I
  output             rx_ref_clk,
  input              rx_data_clk,
  input              rx_data_ready,
  output             rx_data_valid,
  output [11:0]      rx_data_s0,
  output [11:0]      rx_data_s1,
  output [11:0]      rx_data_s2,
  output [11:0]      rx_data_s3,

// DATA O
  output             tx_ref_clk,
  input              tx_data_clk,
  input              tx_data_valid,
  output             tx_data_ready,
  input [11:0]       tx_data_s0,
  input [11:0]       tx_data_s1,
  input [11:0]       tx_data_s2,
  input [11:0]       tx_data_s3
);

localparam OUT_MODE_MAX = 3;
localparam MUX_MODE = OUT_MODE_MAX * IN_MODE + OUT_MODE;
assign hwcfg_port[2:0] =
    (MUX_MODE == OUT_MODE_MAX * 0 + 0) ? 0 :
    (MUX_MODE == OUT_MODE_MAX * 0 + 1) ? 1 :
    (MUX_MODE == OUT_MODE_MAX * 0 + 2) ? 2 :
    (MUX_MODE == OUT_MODE_MAX * 1 + 0) ? 3 :
    (MUX_MODE == OUT_MODE_MAX * 1 + 1) ? 4 :
/*  (MUX_MODE == OUT_MODE_MAX * 1 + 2) ? - :  IMPOSSIBLE */
    (MUX_MODE == OUT_MODE_MAX * 2 + 0) ? 5 :
/*  (MUX_MODE == OUT_MODE_MAX * 2 + 1) ? - :  IMPOSSIBLE */
    (MUX_MODE == OUT_MODE_MAX * 2 + 2) ? 6 : 7;



/////////////////////////////////////////////////////////////
// IO buffers
wire        phy_lml_tmode;
wire        phy_lml_termdis;
wire        phy_lml_inportdis;
wire [11:0] phy_lml_data_in;
wire [11:0] phy_lml_data_out;
wire [11:0] phy_lml_data_out_tmode;
wire        phy_lml_iqsel_in;
wire        phy_lml_iqsel_out;
wire        phy_lml_iqsel_out_tmode;

wire        phy_lml_fclk_tmode;
wire        phy_lml_fclk_out_tmode;
wire        phy_lml_fclk_out;
wire        phy_lml_txnrx_out;

// No control for MCLK for now; add special configuration port
wire        phy_lml_mclk_termdis = 1'b0;
wire        phy_lml_mclk_inportdis = 1'b0;
wire        phy_lml_mclk_in;

genvar j;
generate
  for (j = 0; j < 12; j = j + 1) begin: lml_bufs
    if (IN_MODE != 0) begin: i
    IBUF_INTERMDISABLE phy_data_buf_i(
      .I(lms_io_diq[j]),
      .O(phy_lml_data_in[j]),
      //.IBUFDISABLE(phy_lml_inportdis),
      .INTERMDISABLE(phy_lml_termdis)
    );
    end
    if (OUT_MODE != 0) begin: o
    OBUFT phy_data_buf_o(
      .O(lms_io_diq[j]),
      .I(phy_lml_data_out[j]),
      .T(phy_lml_data_out_tmode[j])
    );
    end
  end
endgenerate
if (IN_MODE != 0) begin
  IBUF_INTERMDISABLE phy_iqsel_buf_i(
    .I(lms_io_iqsel),
    .O(phy_lml_iqsel_in),
    //.IBUFDISABLE(phy_lml_inportdis),
    .INTERMDISABLE(phy_lml_termdis)
  );
end
if (OUT_MODE != 0) begin
  OBUFT phy_iqsel_buf_o(
    .O(lms_io_iqsel),
    .I(phy_lml_iqsel_out),
    .T(phy_lml_iqsel_out_tmode)
  );
end

OBUFT phy_fclk_obuf(
  .O(lms_i_fclk),
  .I(phy_lml_fclk_out),
  .T(phy_lml_fclk_out_tmode)
);

OBUF phy_txnrx_obuf(
  .O(lms_i_txnrx),
  .I(phy_lml_txnrx_out)
);

IBUF_INTERMDISABLE phy_mclk_ibuf(
  .O(phy_lml_mclk_in),
  .I(lms_o_mclk),
  .IBUFDISABLE(phy_lml_mclk_inportdis),
  .INTERMDISABLE(phy_lml_mclk_termdis)
);

wire          idelay_rst;
wire          idelay_refclk;
wire [11:0]   phy_lml_data_in_d;
wire          phy_lml_iqsel_in_d;

genvar i;
generate
  if (USE_IDELAY != 0 && IN_MODE != 0) begin: rx_delay
    (* keep = "TRUE" *)
    IDELAYCTRL idctrl(.REFCLK(idelay_refclk), .RST(idelay_rst), .RDY());

    for (i = 0; i < 12; i=i+1) begin: diq_delay
      IDELAYE2 #(
        .IDELAY_TYPE("VAR_LOAD"),
        .DELAY_SRC("IDATAIN"),
        .IDELAY_VALUE(0),
        .HIGH_PERFORMANCE_MODE("TRUE"),
        .SIGNAL_PATTERN("DATA"),
        .REFCLK_FREQUENCY(400),
        .CINVCTRL_SEL("FALSE"),
        .PIPE_SEL("FALSE")
      ) idelay_rx (
        .C(cfg_rx_idelay_clk),
        .REGRST(0),
        .LD(cfg_rx_idelay_addr == i),
        .CE(0),
        .INC(0),
        .CINVCTRL(0),
        .CNTVALUEIN(cfg_rx_idelay_data),
        .IDATAIN(phy_lml_data_in[i]),
        .DATAIN(),
        .LDPIPEEN(),
        .DATAOUT(phy_lml_data_in_d[i]),
        .CNTVALUEOUT()
      );
    end

    IDELAYE2 #(
      .IDELAY_TYPE("VAR_LOAD"),
      .DELAY_SRC("IDATAIN"),
      .IDELAY_VALUE(0),
      .HIGH_PERFORMANCE_MODE("TRUE"),
      .SIGNAL_PATTERN("DATA"),
      .REFCLK_FREQUENCY(400),
      .CINVCTRL_SEL("FALSE"),
      .PIPE_SEL("FALSE")
    ) idelay_rx (
      .C(cfg_rx_idelay_clk),
      .REGRST(0),
      .LD(cfg_rx_idelay_addr == 12),
      .CE(0),
      .INC(0),
      .CINVCTRL(0),
      .CNTVALUEIN(cfg_rx_idelay_data),
      .IDATAIN(phy_lml_iqsel_in),
      .DATAIN(),
      .LDPIPEEN(),
      .DATAOUT(phy_lml_iqsel_in_d),
      .CNTVALUEOUT()
    );
  end else begin
    assign phy_lml_data_in_d = phy_lml_data_in;
    assign phy_lml_iqsel_in_d = phy_lml_iqsel_in;
  end
endgenerate

wire phy_tx_reset_clkdiv;
wire phy_tx_data_clk;
wire phy_tx_data_clk_div;
wire phy_tx_ce;

wire [11:0] b_tx_data_s0;
wire [11:0] b_tx_data_s1;
wire [11:0] b_tx_data_s2;
wire [11:0] b_tx_data_s3;

generate
  if (OUT_MODE == 2) begin
    for (i = 0; i < 12; i=i+1) begin: diq_tx_full
      OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("DDR"),
        .DATA_WIDTH(4)
      ) oserdese2_lms_diq_tx(
        .RST(phy_tx_reset_clkdiv),
        .D1(b_tx_data_s0[i]),
        .D2(b_tx_data_s1[i]),
        .D3(b_tx_data_s2[i]),
        .D4(b_tx_data_s3[i]),
        .D5(),
        .D6(),
        .D7(),
        .D8(),
        .CLK(phy_tx_data_clk),
        .CLKDIV(phy_tx_data_clk_div),
        .OCE(phy_tx_ce),
        .T1(phy_lml_tmode),
        .T2(phy_lml_tmode),
        .T3(phy_lml_tmode),
        .T4(phy_lml_tmode),
        .TCE(1'b1),
        .TBYTEIN(),
        .TBYTEOUT(),
        .OQ(phy_lml_data_out[i]),
        .TQ(phy_lml_data_out_tmode[i]),
        .OFB(),
        .TFB(),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .SHIFTIN1(),
        .SHIFTIN2()
      );
    end

    OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),
      .DATA_RATE_TQ("DDR"),
      .DATA_WIDTH(4)
    ) oserdese2_lms_iqsel_tx(
      .RST(phy_tx_reset_clkdiv),
      .D1(0),
      .D2(0),
      .D3(1),
      .D4(1),
      .D5(),
      .D6(),
      .D7(),
      .D8(),
      .CLK(phy_tx_data_clk),
      .CLKDIV(phy_tx_data_clk_div),
      .OCE(phy_tx_ce),
      .T1(phy_lml_tmode),
      .T2(phy_lml_tmode),
      .T3(phy_lml_tmode),
      .T4(phy_lml_tmode),
      .TCE(1'b1),
      .TBYTEIN(),
      .TBYTEOUT(),
      .OQ(phy_lml_iqsel_out),
      .TQ(phy_lml_iqsel_out_tmode),
      .OFB(),
      .TFB(),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .SHIFTIN1(),
      .SHIFTIN2()
    );
  end else if (OUT_MODE == 1) begin
    for (i = 0; i < 12; i=i+1) begin: diq_tx_slow
      OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("BUF"),
        .DATA_WIDTH(8),
        .TRISTATE_WIDTH(1)
      ) oserdese2_lms_diq_tx(
        .RST(phy_tx_reset_clkdiv),
        .D1(b_tx_data_s0[i]),
        .D2(b_tx_data_s0[i]),
        .D3(b_tx_data_s1[i]),
        .D4(b_tx_data_s1[i]),
        .D5(b_tx_data_s2[i]),
        .D6(b_tx_data_s2[i]),
        .D7(b_tx_data_s3[i]),
        .D8(b_tx_data_s3[i]),
        .CLK(phy_tx_data_clk),
        .CLKDIV(phy_tx_data_clk_div),
        .OCE(phy_tx_ce),
        .T1(phy_lml_tmode),
        .T2(),
        .T3(),
        .T4(),
        .TCE(1'b1),
        .TBYTEIN(),
        .TBYTEOUT(),
        .OQ(phy_lml_data_out[i]),
        .TQ(phy_lml_data_out_tmode[i]),
        .OFB(),
        .TFB(),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .SHIFTIN1(),
        .SHIFTIN2()
      );
    end

    OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),
      .DATA_RATE_TQ("BUF"),
      .DATA_WIDTH(8),
      .TRISTATE_WIDTH(1)
    ) oserdese2_lms_iqsel_tx(
      .RST(phy_tx_reset_clkdiv),
      .D1(0),
      .D2(0),
      .D3(0),
      .D4(0),
      .D5(1),
      .D6(1),
      .D7(1),
      .D8(1),
      .CLK(phy_tx_data_clk),
      .CLKDIV(phy_tx_data_clk_div),
      .OCE(phy_tx_ce),
      .T1(phy_lml_tmode),
      .T2(),
      .T3(),
      .T4(),
      .TCE(1'b1),
      .TBYTEIN(),
      .TBYTEOUT(),
      .OQ(phy_lml_iqsel_out),
      .TQ(phy_lml_iqsel_out_tmode),
      .OFB(),
      .TFB(),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .SHIFTIN1(),
      .SHIFTIN2()
    );
  end else begin
    assign phy_lml_iqsel_out = 0;
    assign phy_lml_data_out = 0;
  end
endgenerate

//wire phy_rx_reset;
wire phy_rx_reset_clkdiv;
wire phy_rx_data_clk;
wire phy_rx_data_clk_div;
wire phy_rx_iqsel_reset_clkdiv;
wire phy_rx_iqsel_clk;
wire phy_rx_iqsel_clk_div;
wire phy_rx_ce1;
wire phy_rx_ce2;

wire [11:0] phy_rx_data_s0;
wire [11:0] phy_rx_data_s1;
wire [11:0] phy_rx_data_s2;
wire [11:0] phy_rx_data_s3;

wire phy_rx_data_valid;

generate
  if (IN_MODE == 99) begin: inm99
    wire        phy_rx_reset_iddr;
    wire        lms7_rx_in_iqsel_0;
    wire        lms7_rx_in_iqsel_1;
    wire [11:0] lms7_rx_sdr0;
    wire [11:0] lms7_rx_sdr1;

    for (i = 0; i < 12; i=i+1) begin: iddr_diq_rx
      IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),  // 2-cycle delay
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("ASYNC")
      ) iddr_lms_diq_rx (
        .C(phy_rx_data_clk),
        .D(phy_lml_data_in_d[i]),
        .CE(phy_rx_ce1 && phy_rx_ce2),
        .Q1(lms7_rx_sdr0[i]),
        .Q2(lms7_rx_sdr1[i]),
        .R(phy_rx_reset_iddr),
        .S()
      );
    end

    IDDR #(
      .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),  // 2-cycle delay
      .INIT_Q1(1'b0),
      .INIT_Q2(1'b0),
      .SRTYPE("ASYNC")
    ) iddr_lms_iqsel_rx (
      .C(phy_rx_data_clk),
      .D(phy_lml_iqsel_in_d),
      .CE(phy_rx_ce1 && phy_rx_ce2),
      .Q1(lms7_rx_in_iqsel_0),
      .Q2(lms7_rx_in_iqsel_1),
      .R(phy_rx_reset_iddr),
      .S()
    );

    lms7_rx_iddr lms7_rx_iddr(
      .sdr_reset(phy_rx_reset_iddr),
      .sdr_enable(phy_rx_ce1 && phy_rx_ce2),
      .rx_clk(phy_rx_data_clk),
      .in_sdr_0(lms7_rx_sdr0),
      .in_sdr_1(lms7_rx_sdr1),
      .in_iqsel_0(lms7_rx_in_iqsel_0),
      .in_iqsel_1(lms7_rx_in_iqsel_1),
      .sdr_ai(phy_rx_data_s0),
      .sdr_aq(phy_rx_data_s1),
      .sdr_bi(phy_rx_data_s2),
      .sdr_bq(phy_rx_data_s3),
      .sdr_valid(phy_rx_data_valid),
      .o_rxiq_miss(stat_rx_corr),
      .o_rxiq_odd(stat_rx_frame_err),
      .o_lock_ai(),
      .o_lock_bi(),
      .o_lock_aq(),
      .o_lock_bq()
    );

    assign phy_rx_reset_iddr = phy_rx_reset_clkdiv; // CLKDIV==CLK in this mode
  end else if (IN_MODE == 50) begin
    wire [11:0] phy_rx_data_s00;
    wire [11:0] phy_rx_data_s01;
    wire [11:0] phy_rx_data_s10;
    wire [11:0] phy_rx_data_s11;
    wire [11:0] phy_rx_data_s20;
    wire [11:0] phy_rx_data_s21;
    wire [11:0] phy_rx_data_s30;
    wire [11:0] phy_rx_data_s31;
    wire [7:0]  rx_iqsel_div_p;
    reg  [11:0] phy_rx_data_p;

    wire        rx_bitslip_data;
    wire        rx_bitslip_iqsel;
    wire [3:0]  rx_iqsel_div;

    for (i = 0; i < 12; i=i+1) begin: diq_rx
      always @(posedge phy_rx_data_clk_div) begin
        phy_rx_data_p[i] <= phy_rx_data_s31[i];
      end
      ISERDESE2 #(
        .DATA_RATE("DDR"),
        .DATA_WIDTH(8),
        .INTERFACE_TYPE("NETWORKING"),
        .IOBDELAY((USE_IDELAY != 0) ? "IFD" : "NONE")
      ) iserdese2_lms_diq_rx_pri(
        .RST(phy_rx_reset_clkdiv),
        .D(phy_lml_data_in[i]),
        .DDLY(phy_lml_data_in_d[i]),
        .Q1(phy_rx_data_s31[i]),
        .Q2(phy_rx_data_s30[i]),
        .Q3(phy_rx_data_s21[i]),
        .Q4(phy_rx_data_s20[i]),
        .Q5(phy_rx_data_s11[i]),
        .Q6(phy_rx_data_s10[i]),
        .Q7(phy_rx_data_s01[i]),
        .Q8(phy_rx_data_s00[i]),
        .CLK(phy_rx_data_clk),
        .CLKB(~phy_rx_data_clk),
        .OCLK(1'b0),
        .OCLKB(1'b0),
        .CLKDIV(phy_rx_data_clk_div),
        .CLKDIVP(1'b0),
        .DYNCLKSEL(1'b0),
        .DYNCLKDIVSEL(1'b0),
        .CE1(phy_rx_ce1),
        .CE2(phy_rx_ce2),
        .BITSLIP(rx_bitslip_data),
        .OFB(1'b0),
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .O()
      );
      wire [2:0] sb0 = { phy_rx_data_p[i],   phy_rx_data_s00[i], phy_rx_data_s01[i] };
      wire [2:0] sb1 = { phy_rx_data_s01[i], phy_rx_data_s10[i], phy_rx_data_s11[i] };
      wire [2:0] sb2 = { phy_rx_data_s11[i], phy_rx_data_s20[i], phy_rx_data_s21[i] };
      wire [2:0] sb3 = { phy_rx_data_s21[i], phy_rx_data_s30[i], phy_rx_data_s31[i] };

      assign phy_rx_data_s0[i] = (sb0[0]);
      assign phy_rx_data_s1[i] = (sb1[0]);
      assign phy_rx_data_s2[i] = (sb2[0]);
      assign phy_rx_data_s3[i] = (sb3[0]);

    end

    (* keep = "TRUE" *)
    ISERDESE2 #(
      .DATA_RATE("DDR"),
      .DATA_WIDTH(8),
      .INTERFACE_TYPE("NETWORKING"),
      .IOBDELAY((USE_IDELAY != 0) ? "IFD" : "NONE")
    ) iserdese2_lms_iqsel_rx(
      .RST(phy_rx_iqsel_reset_clkdiv),
      .D(phy_lml_iqsel_in),
      .DDLY(phy_lml_iqsel_in_d),
      .Q1(rx_iqsel_div_p[7]),
      .Q2(rx_iqsel_div_p[6]),
      .Q3(rx_iqsel_div_p[5]),
      .Q4(rx_iqsel_div_p[4]),
      .Q5(rx_iqsel_div_p[3]),
      .Q6(rx_iqsel_div_p[2]),
      .Q7(rx_iqsel_div_p[1]),
      .Q8(rx_iqsel_div_p[0]),
      .CLK(phy_rx_iqsel_clk),
      .CLKB(~phy_rx_iqsel_clk),
      .OCLK(1'b0),
      .OCLKB(1'b0),
      .CLKDIV(phy_rx_iqsel_clk_div),
      .CLKDIVP(1'b0),
      .DYNCLKSEL(1'b0),
      .DYNCLKDIVSEL(1'b0),
      .CE1(phy_rx_ce1),
      .CE2(phy_rx_ce2),
      .BITSLIP(rx_bitslip_iqsel),
      .OFB(1'b0),
      .SHIFTIN1(1'b0),
      .SHIFTIN2(1'b0),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .O()
    );
    wire iqsel_aligned    =  (rx_iqsel_div_p == 8'b11110000);
    wire iqsel_misaligned = ((rx_iqsel_div_p == 8'b01111000) ||
                             (rx_iqsel_div_p == 8'b00111100) ||
                             (rx_iqsel_div_p == 8'b00011110) ||
                             (rx_iqsel_div_p == 8'b00001111) ||
                             (rx_iqsel_div_p == 8'b10000111) ||
                             (rx_iqsel_div_p == 8'b11000011) ||
                             (rx_iqsel_div_p == 8'b11100001));

    wire iqsel_err = (~iqsel_aligned && ~iqsel_misaligned);


    reg       iqsel_bitslip;
    reg [3:0] iqsel_check_delay;
    reg [STAT_DIAG_BITS-1:0] frame_err;
    reg [STAT_DIAG_BITS-1:0] frame_corr;
    always @(posedge phy_rx_iqsel_clk_div) begin
      if (phy_rx_iqsel_reset_clkdiv) begin
        iqsel_check_delay <= 0;
        iqsel_bitslip     <= 0;
        frame_err         <= 0;
        frame_corr        <= 0;
      end else begin
        iqsel_bitslip     <= 0;
        if (iqsel_check_delay != 4'b1111) begin
          iqsel_check_delay <= iqsel_check_delay + 1'b1;
        end else begin
          if (iqsel_misaligned) begin
            frame_corr        <= frame_corr + 1'b1;
            iqsel_bitslip     <= 1'b1;
            iqsel_check_delay <= 0;
          end else if (~iqsel_aligned) begin
            frame_err <= frame_err + 1'b1;
          end
        end
      end
    end

    assign rx_bitslip_iqsel = iqsel_bitslip;
    assign rx_bitslip_data  = iqsel_bitslip; // TODO clock phase aligner
    assign stat_rx_frame_err = frame_err;
    assign stat_rx_corr = { frame_corr, cfg_port_tx, phy_lml_inportdis, phy_rx_reset_clkdiv, cfg_port_enable, iqsel_check_delay, rx_iqsel_div_p };
    assign phy_rx_data_valid = 1'b1;

  end else if (IN_MODE != 0) begin
    wire       rx_bitslip_data;
    wire       rx_bitslip_iqsel;
    wire [3:0] rx_iqsel_div;
    wire       iqsel_data_bitslip;

    for (i = 0; i < 12; i=i+1) begin: diq_rx
      (* keep = "TRUE" *)
      ISERDESE2 #(
        .DATA_RATE("DDR"),
        .DATA_WIDTH(4),
        .INTERFACE_TYPE("NETWORKING"),
        .IOBDELAY((USE_IDELAY != 0) ? "IFD" : "NONE")
      ) iserdese2_lms_diq_rx(
        .RST(phy_rx_reset_clkdiv),
        .D(phy_lml_data_in[i]),
        .DDLY(phy_lml_data_in_d[i]),
        .Q1(phy_rx_data_s3[i]),
        .Q2(phy_rx_data_s2[i]),
        .Q3(phy_rx_data_s1[i]),
        .Q4(phy_rx_data_s0[i]),
        .Q5(),
        .Q6(),
        .Q7(),
        .Q8(),
        .CLK(phy_rx_data_clk),
        .CLKB(~phy_rx_data_clk),
        .OCLK(1'b0),
        .OCLKB(1'b0),
        .CLKDIV(phy_rx_data_clk_div),
        .CLKDIVP(1'b0),
        .DYNCLKSEL(1'b0),
        .DYNCLKDIVSEL(1'b0),
        .CE1(phy_rx_ce1),
        .CE2(phy_rx_ce2),
        .BITSLIP(rx_bitslip_data),
        .OFB(1'b0),
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .O()
      );
    end

    (* keep = "TRUE" *)
    ISERDESE2 #(
      .DATA_RATE("DDR"),
      .DATA_WIDTH(4),
      .INTERFACE_TYPE("NETWORKING"),
      .IOBDELAY((USE_IDELAY != 0) ? "IFD" : "NONE")
    ) iserdese2_lms_iqsel_rx(
      .RST(phy_rx_iqsel_reset_clkdiv),
      .D(phy_lml_iqsel_in),
      .DDLY(phy_lml_iqsel_in_d),
      .Q1(rx_iqsel_div[3]),
      .Q2(rx_iqsel_div[2]),
      .Q3(rx_iqsel_div[1]),
      .Q4(rx_iqsel_div[0]),
      .Q5(),
      .Q6(),
      .Q7(),
      .Q8(),
      .CLK(phy_rx_iqsel_clk),
      .CLKB(~phy_rx_iqsel_clk),
      .OCLK(1'b0),
      .OCLKB(1'b0),
      .CLKDIV(phy_rx_iqsel_clk_div),
      .CLKDIVP(1'b0),
      .DYNCLKSEL(1'b0),
      .DYNCLKDIVSEL(1'b0),
      .CE1(phy_rx_ce1),
      .CE2(phy_rx_ce2),
      .BITSLIP(rx_bitslip_iqsel),
      .OFB(1'b0),
      .SHIFTIN1(1'b0),
      .SHIFTIN2(1'b0),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .O()
    );

    wire iqsel_aligned = (rx_iqsel_div == 4'b1100);
    wire iqsel_misaligned = ((rx_iqsel_div == 4'b0110) ||
                             (rx_iqsel_div == 4'b0011) ||
                             (rx_iqsel_div == 4'b1001));

    wire iqsel_err = (~iqsel_aligned && ~iqsel_misaligned);

    reg       iqsel_bitslip;
    reg [3:0] iqsel_check_delay;
    reg [3:0] iqsel_upd_delay;
    reg [STAT_DIAG_BITS-1:0] frame_err;
    reg [7:0] frame_corr;
    reg [7:0] frame_corr2;

    always @(posedge phy_rx_iqsel_clk_div) begin
      if (phy_rx_iqsel_reset_clkdiv) begin
        iqsel_check_delay <= 0;
        iqsel_upd_delay   <= 0;
        //iqsel_bitslip     <= 0;
        frame_err         <= 0;
        frame_corr        <= 0;
      end else begin
        //iqsel_bitslip     <= 0;
        if (iqsel_check_delay != 4'b1111) begin
          iqsel_check_delay <= iqsel_check_delay + 1'b1;
        end else begin
          if (iqsel_misaligned) begin
            iqsel_upd_delay   <= iqsel_upd_delay + 1'b1;
            if (iqsel_upd_delay ==  4'b1111) begin
              frame_corr        <= frame_corr + 1'b1;
              //iqsel_bitslip     <= 1'b1;
              iqsel_check_delay <= 0;
            end
          end else if (~iqsel_aligned) begin
            frame_err <= frame_err + 1'b1;
            iqsel_upd_delay <= 0;
          end
        end
      end
    end
    always @(posedge phy_rx_iqsel_clk_div or posedge phy_rx_iqsel_reset_clkdiv) begin
      if (phy_rx_iqsel_reset_clkdiv) begin
        iqsel_bitslip <= 0;
      end else begin
        iqsel_bitslip <= 0;
        if ((iqsel_check_delay == 4'b1111) && (iqsel_upd_delay ==  4'b1111) && iqsel_misaligned)
          iqsel_bitslip <= 1'b1;
      end
    end

    wire reg_iqsel_st_stat;
    if (IRX_IQSEL_PHASE != 0) begin
      // 1-bit gray counter
      (* ASYNC_REG = "TRUE" *) reg reg_data_st_0;
      (* ASYNC_REG = "TRUE" *) reg reg_data_st_1;

      reg reg_data_st;
      reg reg_rx_bitslip_data;
      always @(posedge phy_rx_data_clk_div or posedge phy_rx_reset_clkdiv) begin
        if (phy_rx_reset_clkdiv) begin
          reg_data_st_0       <= 0;
          reg_data_st_1       <= 0;
          reg_data_st         <= 0;
          reg_rx_bitslip_data <= 0;
        end else begin
          reg_data_st_0       <= frame_corr[0];
          reg_data_st_1       <= reg_data_st_0;
          reg_data_st         <= reg_data_st_1;
          reg_rx_bitslip_data <= (reg_data_st != reg_data_st_1);
        end
      end

      always @(posedge phy_rx_data_clk_div) begin
        if (phy_rx_reset_clkdiv) begin
          frame_corr2 <= 0;
        end else begin
          if (reg_rx_bitslip_data)
            frame_corr2 <= frame_corr2 + 1'b1;
        end
      end

      assign rx_bitslip_data  = reg_rx_bitslip_data;
      assign reg_iqsel_st_stat = reg_data_st;
    end else begin
      assign rx_bitslip_data  = iqsel_bitslip;
      assign reg_iqsel_st_stat = 1'b0;
    end

    assign rx_bitslip_iqsel = iqsel_bitslip;
    assign stat_rx_frame_err = frame_err;
    assign stat_rx_corr = { frame_corr2[7:0], frame_corr[7:0], 4'b0, iqsel_check_delay, reg_iqsel_st_stat, phy_rx_iqsel_reset_clkdiv, phy_rx_reset_clkdiv, cfg_port_enable, rx_iqsel_div };
    assign phy_rx_data_valid = 1'b1;
  end else begin
    assign phy_rx_data_s0 = 0;
    assign phy_rx_data_s1 = 0;
    assign phy_rx_data_s2 = 0;
    assign phy_rx_data_s3 = 0;
    assign stat_rx_frame_err = ~0;
    assign stat_rx_corr = ~0;
    assign phy_rx_data_valid = 0;
  end
endgenerate

wire phy_fclk_reset_oddr;
wire phy_fclk_reset;
wire phy_fclk_clk;
wire phy_fclk_clk_div;
// FCLK for IN & OUT
generate
  if (IN_MODE == 2 || IN_MODE == 50 || OUT_MODE == 2) begin: fclk_phase
`ifdef OSERDESE2_FCLK
    OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),
      .DATA_RATE_TQ("DDR"),
      .DATA_WIDTH(4)
    ) oserdese2_lms_clk_tx(
      .RST(phy_fclk_reset),
      .D1(1),
      .D2(0),
      .D3(1),
      .D4(0),
      .D5(),
      .D6(),
      .D7(),
      .D8(),
      .CLK(phy_fclk_clk),
      .CLKDIV(phy_fclk_clk_div),
      .OCE(1'b1),
      .T1(phy_lml_fclk_tmode),
      .T2(phy_lml_fclk_tmode),
      .T3(phy_lml_fclk_tmode),
      .T4(phy_lml_fclk_tmode),
      .TCE(1'b1),
      .TBYTEIN(),
      .TBYTEOUT(),
      .OQ(phy_lml_fclk_out),
      .TQ(phy_lml_fclk_out_tmode),
      .OFB(),
      .TFB(),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .SHIFTIN1(),
      .SHIFTIN2()
    );
`else
    ODDR #(
      .DDR_CLK_EDGE("OPPOSITE_EDGE"),
      .SRTYPE("SYNC"),
      .INIT(0)
    ) oddr_lms_clk_tx (
      .Q(phy_lml_fclk_out),
      .C(phy_fclk_clk),
      .CE(1'b1),
      .D1(1'b1),
      .D2(1'b0),
      .R(1'b0)
    );
    assign phy_lml_fclk_out_tmode = phy_lml_fclk_tmode;
`endif
  end else if (OUT_MODE == 1) begin: fclk_static
    OSERDESE2 #(
      .DATA_RATE_OQ("DDR"),
      .DATA_RATE_TQ("BUF"),
      .DATA_WIDTH(8),
      .TRISTATE_WIDTH(1)
    ) oserdese2_lms_clk_tx(
      .RST(phy_tx_reset_clkdiv),
      .D1(0),
      .D2(1),
      .D3(1),
      .D4(0),
      .D5(0),
      .D6(1),
      .D7(1),
      .D8(0),
      .CLK(phy_tx_data_clk),
      .CLKDIV(phy_tx_data_clk_div),
      .OCE(1'b1),
      .T1(phy_lml_fclk_tmode),
      .T2(),
      .T3(),
      .T4(),
      .TCE(1'b1),
      .TBYTEIN(),
      .TBYTEOUT(),
      .OQ(phy_lml_fclk_out),
      .TQ(phy_lml_fclk_out_tmode),
      .OFB(),
      .TFB(),
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .SHIFTIN1(),
      .SHIFTIN2()
    );
  end else begin
    assign phy_lml_fclk_out = 1'b0;
    assign phy_lml_fclk_out_tmode = phy_lml_fclk_tmode;
  end
endgenerate

/////////////////////////////////////////////////////////////
// Clocking
wire mmcm_gen_data_clk;
wire mmcm_gen_data_clk_div;
wire mmcm_gen_iqsel_clk;
wire mmcm_gen_iqsel_clk_div;
wire mmcm_gen_refclk;
wire mmcm_gen_id_refclk;
wire mmcm_ready;

generate
  wire mrcc_in_bufio;
  if (IN_MODE == 1 || OUT_MODE == 1) begin: mrcc_bufio
    BUFIO in_bufio(.I(phy_lml_mclk_in), .O(mrcc_in_bufio));
  end

  if (IN_MODE == 99) begin: clk_mode99
    BUFH bufh_mclk(.I(phy_lml_mclk_in), .O(phy_rx_data_clk));
    assign phy_rx_data_clk_div = phy_rx_data_clk;
    assign idelay_refclk = phy_rx_data_clk;

    BUFR #(.BUFR_DIVIDE(2)) mrcc_div2(
      .I(phy_lml_mclk_in),
      .O(rx_ref_clk),
      .CE(1'b1),
      .CLR(1'b0)
    );
  end else if (IN_MODE == 2 || IN_MODE == 50) begin: clk_mode2
    assign phy_rx_data_clk      = mmcm_gen_data_clk;
    assign phy_rx_data_clk_div  = mmcm_gen_data_clk_div;
    assign phy_rx_iqsel_clk     = (IRX_IQSEL_PHASE != 0) ? mmcm_gen_iqsel_clk     : phy_rx_data_clk;
    assign phy_rx_iqsel_clk_div = (IRX_IQSEL_PHASE != 0) ? mmcm_gen_iqsel_clk_div : phy_rx_data_clk_div;
    assign rx_ref_clk           = mmcm_gen_refclk;
    BUFG id_bufh(.I(mmcm_gen_id_refclk), .O(idelay_refclk)); //FIXME to BUFH
  end else if (IN_MODE == 1) begin: clk_mode1
    assign phy_rx_data_clk = mrcc_in_bufio;
    BUFR #(.BUFR_DIVIDE(2)) mrcc_div2(
      .I(phy_lml_mclk_in),
      .O(phy_rx_data_clk_div),
      .CE(1'b1),
      .CLR(1'b0)
    );
    assign phy_rx_iqsel_clk     = phy_rx_data_clk;
    assign phy_rx_iqsel_clk_div = phy_rx_data_clk_div;

    assign rx_ref_clk           = phy_rx_data_clk_div; // < extra buffering ?
    //assign idelay_refclk        = phy_rx_data_clk; // CHECK ME
    BUFG id_bufh(.I(phy_lml_mclk_in), .O(idelay_refclk)); //FIXME to BUFH
  end else begin
    assign phy_rx_data_clk      = 1'b0;
    assign phy_rx_data_clk_div  = 1'b0;
    assign rx_ref_clk           = 1'b0;
    assign idelay_refclk        = 1'b0;
  end
  if (OUT_MODE == 2) begin
    assign phy_tx_data_clk     = mmcm_gen_data_clk;
    assign phy_tx_data_clk_div = mmcm_gen_data_clk_div;
    assign tx_ref_clk          = mmcm_gen_refclk;
  end else if (OUT_MODE == 1) begin
    assign phy_tx_data_clk = mrcc_in_bufio;
    BUFR #(.BUFR_DIVIDE(4)) mrcc_div4(
      .I(phy_lml_mclk_in),
      .O(phy_tx_data_clk_div),
      .CE(1'b1),
      .CLR(1'b0)
    );
    //assign tx_ref_clk = phy_tx_data_clk_div; // < extra buffering ?
    BUFG refbuf(.I(phy_tx_data_clk_div), .O(tx_ref_clk));
  end else begin
    assign phy_tx_data_clk     = 1'b0;
    assign phy_tx_data_clk_div = 1'b0;
    assign tx_ref_clk          = 1'b0;

    assign phy_lml_iqsel_out_tmode = phy_lml_tmode;
    for (i = 0; i < 12; i=i+1) begin
      assign phy_lml_data_out_tmode[i] = phy_lml_tmode;
    end
  end
endgenerate

generate
  if (OUT_MODE == 2 || IN_MODE == 2 || IN_MODE == 50) begin: mmcm_gen
    wire mmcm_gen_fclk;
    wire mmcm_gen_int_clk;
    wire mmcm_gen_int2_clk;
`ifdef OSERDESE2_FCLK
    BUFR #(.BUFR_DIVIDE(2)) buf_fclk_div2(
      .I(mmcm_gen_fclk),
      .O(phy_fclk_clk_div),
      .CE(1'b1),
      .CLR(~mmcm_ready)
    );
`endif
    BUFIO bufio_fclk(.I(mmcm_gen_fclk), .O(phy_fclk_clk));

    BUFR #(.BUFR_DIVIDE((IN_MODE == 50) ? 4 : 2)) buf_data_div2(
      .I(mmcm_gen_int_clk),
      .O(mmcm_gen_data_clk_div),
      .CE(1'b1),
      .CLR(~mmcm_ready)
    );
    BUFIO bufio_data(.I(mmcm_gen_int_clk), .O(mmcm_gen_data_clk));

    if (IRX_IQSEL_PHASE != 0) begin
      BUFR #(.BUFR_DIVIDE((IN_MODE == 50) ? 4 : 2)) buf_iqsel_div2(
        .I(mmcm_gen_int2_clk),
        .O(mmcm_gen_iqsel_clk_div),
        .CE(1'b1),
        .CLR(~mmcm_ready)
      );
      BUFIO bufio_data(.I(mmcm_gen_int2_clk), .O(mmcm_gen_iqsel_clk));
    end else begin
      assign mmcm_gen_iqsel_clk_div = 1'b0;
      assign mmcm_gen_iqsel_clk = 1'b0;
    end

    wire clkfb_bufgout;
    wire clkfb_bufgin;
    assign clkfb_bufgin = clkfb_bufgout;

    MMCME2_ADV #(
      .BANDWIDTH("LOW"),    // "HIGH"
      .DIVCLK_DIVIDE(1),    // (1 to 106)

      .CLKFBOUT_MULT_F(2),
      .CLKFBOUT_PHASE(0.0),
      .CLKFBOUT_USE_FINE_PS("FALSE"),

      .CLKIN1_PERIOD(2.5),
      .REF_JITTER1(0.010),

      .CLKIN2_PERIOD(2.5),
      .REF_JITTER2(0.010),

      .CLKOUT0_DIVIDE_F(2),
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT0_PHASE(90.0),
      .CLKOUT0_USE_FINE_PS("FALSE"),

      .CLKOUT1_DIVIDE(2),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT1_PHASE(0.0),
      .CLKOUT1_USE_FINE_PS("FALSE"),

      .CLKOUT2_DIVIDE(2),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT2_PHASE(0.0),
      .CLKOUT2_USE_FINE_PS("FALSE"),

      .CLKOUT3_DIVIDE(2),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT3_PHASE(0.0),
      .CLKOUT3_USE_FINE_PS("FALSE"),

      .CLKOUT4_DIVIDE(2),
      .CLKOUT4_DUTY_CYCLE(0.5),
      .CLKOUT4_PHASE(0.0),
      .CLKOUT4_USE_FINE_PS("FALSE"),
      .CLKOUT4_CASCADE("TRUE"),

      .CLKOUT5_DIVIDE(2),
      .CLKOUT5_DUTY_CYCLE(0.5),
      .CLKOUT5_PHASE(0.0),
      .CLKOUT5_USE_FINE_PS("FALSE"),

      .CLKOUT6_DIVIDE(2),
      .CLKOUT6_DUTY_CYCLE(0.5),
      .CLKOUT6_PHASE(0.0),
      .CLKOUT6_USE_FINE_PS("FALSE"),

      .COMPENSATION("INTERNAL"), // "ZHOLD"
      .STARTUP_WAIT("FALSE")
   ) mmcme2 (
      .CLKFBOUT(clkfb_bufgin),
      .CLKFBOUTB(),

      .CLKFBSTOPPED(cfg_mmcm_drp_gpio_in[2]),
      .CLKINSTOPPED(cfg_mmcm_drp_gpio_in[1]),

      // Clock outputs
      .CLKOUT0(mmcm_gen_fclk),
      .CLKOUT0B(),
      .CLKOUT1(mmcm_gen_int_clk),
      .CLKOUT1B(),
      .CLKOUT2(mmcm_gen_int2_clk),
      .CLKOUT2B(),
      .CLKOUT3(),
      .CLKOUT3B(),
      .CLKOUT4(mmcm_gen_refclk),
      .CLKOUT5(mmcm_gen_id_refclk),
      .CLKOUT6(),

      // DRP Ports
      .DO(cfg_mmcm_drp_do), // (16-bits)
      .DRDY(cfg_mmcm_drp_drdy),
      .DADDR(cfg_mmcm_drp_daddr), // 5 bits
      .DCLK(cfg_mmcm_drp_dclk),
      .DEN(cfg_mmcm_drp_den),
      .DI(cfg_mmcm_drp_di), // 16 bits
      .DWE(cfg_mmcm_drp_dwe),

      .LOCKED(cfg_mmcm_drp_gpio_in[0]),
      .CLKFBIN(clkfb_bufgout),

      // Clock inputs
      .CLKIN1(phy_lml_mclk_in),
      .CLKIN2(),
      .CLKINSEL(1'b1 /*cfg_mmcm_drp_gpio_out[0]*/), //High = CLKIN1, Low = CLKIN2

      // Fine phase shifting
      .PSDONE(),
      .PSCLK(1'b0),
      .PSEN(1'b0),
      .PSINCDEC(1'b0),

      .PWRDWN(cfg_mmcm_drp_gpio_out[2]),
      .RST(cfg_mmcm_drp_gpio_out[1])
    );
    assign cfg_mmcm_drp_gpio_in[3] = 0;
    assign mmcm_ready = cfg_mmcm_drp_gpio_in[0];
  end else begin
    assign cfg_mmcm_drp_gpio_in = 4'b0000;
    assign cfg_mmcm_drp_do = 0;
    assign cfg_mmcm_drp_drdy = 1'b1;

    assign phy_fclk_clk = 1'b0;
    assign phy_fclk_clk_div = 1'b0;
  end
endgenerate

/////////////////////////////////////////////////////////////
// DATA OUT (LMS IN)
generate
  if (OUT_MODE != 0) begin: tx_fifo
    wire        wr_full;
    assign      tx_data_ready = ~wr_full;

    wire        b_almostempty;
    reg         b_rden;
    always @(posedge phy_tx_data_clk_div) begin
      if (phy_tx_reset_clkdiv) begin
        b_rden <= 1'b0;
      end else begin
        if (~b_rden && ~b_almostempty)
          b_rden <= 1'b1;
      end
    end

    OUT_FIFO #(
      .ARRAY_MODE("ARRAY_MODE_4_X_4"),
      .ALMOST_EMPTY_VALUE(1),
      .ALMOST_FULL_VALUE(1)
    ) out_fifo (
      .D0({ 4'h0, tx_data_s0[0], tx_data_s1[0], tx_data_s2[0], tx_data_s3[0]}),
      .D1({ 4'h0, tx_data_s0[1], tx_data_s1[1], tx_data_s2[1], tx_data_s3[1]}),
      .D2({ 4'h0, tx_data_s0[2], tx_data_s1[2], tx_data_s2[2], tx_data_s3[2]}),
      .D3({ 4'h0, tx_data_s0[3], tx_data_s1[3], tx_data_s2[3], tx_data_s3[3]}),
      .D4({ 4'h0, tx_data_s0[4], tx_data_s1[4], tx_data_s2[4], tx_data_s3[4]}),

      .D7({ 4'h0, tx_data_s0[7], tx_data_s1[7], tx_data_s2[7], tx_data_s3[7]}),
      .D8({ 4'h0, tx_data_s0[8], tx_data_s1[8], tx_data_s2[8], tx_data_s3[8]}),
      .D9({ 4'h0, tx_data_s0[9], tx_data_s1[9], tx_data_s2[9], tx_data_s3[9]}),

      .D5({ tx_data_s0[10], tx_data_s1[10], tx_data_s2[10], tx_data_s3[10],
            tx_data_s0[5],  tx_data_s1[5],  tx_data_s2[5],  tx_data_s3[5]}),
      .D6({ tx_data_s0[11], tx_data_s1[11], tx_data_s2[11], tx_data_s3[11],
            tx_data_s0[6],  tx_data_s1[6],  tx_data_s2[6],  tx_data_s3[6]}),

      .Q0({ b_tx_data_s0[0], b_tx_data_s1[0], b_tx_data_s2[0], b_tx_data_s3[0]}),
      .Q1({ b_tx_data_s0[1], b_tx_data_s1[1], b_tx_data_s2[1], b_tx_data_s3[1]}),
      .Q2({ b_tx_data_s0[2], b_tx_data_s1[2], b_tx_data_s2[2], b_tx_data_s3[2]}),
      .Q3({ b_tx_data_s0[3], b_tx_data_s1[3], b_tx_data_s2[3], b_tx_data_s3[3]}),
      .Q4({ b_tx_data_s0[4], b_tx_data_s1[4], b_tx_data_s2[4], b_tx_data_s3[4]}),

      .Q7({ b_tx_data_s0[7], b_tx_data_s1[7], b_tx_data_s2[7], b_tx_data_s3[7]}),
      .Q8({ b_tx_data_s0[8], b_tx_data_s1[8], b_tx_data_s2[8], b_tx_data_s3[8]}),
      .Q9({ b_tx_data_s0[9], b_tx_data_s1[9], b_tx_data_s2[9], b_tx_data_s3[9]}),

      .Q5({ b_tx_data_s0[10], b_tx_data_s1[10], b_tx_data_s2[10], b_tx_data_s3[10],
            b_tx_data_s0[5],  b_tx_data_s1[5],  b_tx_data_s2[5],  b_tx_data_s3[5]}),
      .Q6({ b_tx_data_s0[11], b_tx_data_s1[11], b_tx_data_s2[11], b_tx_data_s3[11],
            b_tx_data_s0[6],  b_tx_data_s1[6],  b_tx_data_s2[6],  b_tx_data_s3[6]}),

      .RDCLK(phy_tx_data_clk_div),
      .RDEN(b_rden),
      .ALMOSTEMPTY(b_almostempty),
      .EMPTY(),

      .WRCLK(tx_data_clk),
      .WREN(tx_data_valid /* && tx_data_ready */),
      .ALMOSTFULL(),
      .FULL(wr_full),

      .RESET(phy_tx_reset_clkdiv)
    );
  end else begin
    assign      tx_data_ready = 1'b0;
  end
endgenerate


/////////////////////////////////////////////////////////////
// DATA IN (LMS OUT)
generate
  if (IN_MODE != 0 && IN_FIFO != 0) begin: rx_fifo
    reg wren_0 = 1'b0;
    reg wren_1 = 1'b0;
    always @(posedge phy_rx_data_clk_div) begin
      wren_0 <= ~phy_rx_reset_clkdiv;
      wren_1 <= wren_0;
    end

    (* ASYNC_REG = "TRUE" *) reg rden_0 = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg rden_1 = 1'b0;
    always @(posedge rx_data_clk) begin
      rden_0 <= wren_1;
      rden_1 <= rden_0;
    end
    assign rx_data_valid = rden_1;

    (* keep = "TRUE" *)
    IN_FIFO #(
      .ARRAY_MODE("ARRAY_MODE_4_X_4"),
      .ALMOST_EMPTY_VALUE(1),
      .ALMOST_FULL_VALUE(1)
    ) in_fifo (
      .D0({ 4'h0, phy_rx_data_s0[0], phy_rx_data_s1[0], phy_rx_data_s2[0], phy_rx_data_s3[0]}),
      .D1({ 4'h0, phy_rx_data_s0[1], phy_rx_data_s1[1], phy_rx_data_s2[1], phy_rx_data_s3[1]}),
      .D2({ 4'h0, phy_rx_data_s0[2], phy_rx_data_s1[2], phy_rx_data_s2[2], phy_rx_data_s3[2]}),
      .D3({ 4'h0, phy_rx_data_s0[3], phy_rx_data_s1[3], phy_rx_data_s2[3], phy_rx_data_s3[3]}),
      .D4({ 4'h0, phy_rx_data_s0[4], phy_rx_data_s1[4], phy_rx_data_s2[4], phy_rx_data_s3[4]}),

      .D7({ 4'h0, phy_rx_data_s0[7], phy_rx_data_s1[7], phy_rx_data_s2[7], phy_rx_data_s3[7]}),
      .D8({ 4'h0, phy_rx_data_s0[8], phy_rx_data_s1[8], phy_rx_data_s2[8], phy_rx_data_s3[8]}),
      .D9({ 4'h0, phy_rx_data_s0[9], phy_rx_data_s1[9], phy_rx_data_s2[9], phy_rx_data_s3[9]}),

      .D5({ phy_rx_data_s0[10], phy_rx_data_s1[10], phy_rx_data_s2[10], phy_rx_data_s3[10],
            phy_rx_data_s0[5],  phy_rx_data_s1[5],  phy_rx_data_s2[5],  phy_rx_data_s3[5]}),
      .D6({ phy_rx_data_s0[11], phy_rx_data_s1[11], phy_rx_data_s2[11], phy_rx_data_s3[11],
            phy_rx_data_s0[6],  phy_rx_data_s1[6],  phy_rx_data_s2[6],  phy_rx_data_s3[6]}),

      .Q0({ rx_data_s0[0], rx_data_s1[0], rx_data_s2[0], rx_data_s3[0]}),
      .Q1({ rx_data_s0[1], rx_data_s1[1], rx_data_s2[1], rx_data_s3[1]}),
      .Q2({ rx_data_s0[2], rx_data_s1[2], rx_data_s2[2], rx_data_s3[2]}),
      .Q3({ rx_data_s0[3], rx_data_s1[3], rx_data_s2[3], rx_data_s3[3]}),
      .Q4({ rx_data_s0[4], rx_data_s1[4], rx_data_s2[4], rx_data_s3[4]}),

      .Q7({ rx_data_s0[7], rx_data_s1[7], rx_data_s2[7], rx_data_s3[7]}),
      .Q8({ rx_data_s0[8], rx_data_s1[8], rx_data_s2[8], rx_data_s3[8]}),
      .Q9({ rx_data_s0[9], rx_data_s1[9], rx_data_s2[9], rx_data_s3[9]}),

      .Q5({ rx_data_s0[10], rx_data_s1[10], rx_data_s2[10], rx_data_s3[10],
            rx_data_s0[5],  rx_data_s1[5],  rx_data_s2[5],  rx_data_s3[5]}),
      .Q6({ rx_data_s0[11], rx_data_s1[11], rx_data_s2[11], rx_data_s3[11],
            rx_data_s0[6],  rx_data_s1[6],  rx_data_s2[6],  rx_data_s3[6]}),

      .RDCLK(rx_data_clk),
      .RDEN(rx_data_valid),      // TODO
      .ALMOSTEMPTY(/*b_rx_empty*/),  // TODO
      .EMPTY(),

      .WRCLK(phy_rx_data_clk_div),
      .WREN(wren_1 && phy_rx_data_valid),
      .ALMOSTFULL(),
      .FULL(),

      .RESET(phy_rx_reset_clkdiv)
    );
  end else if (IN_MODE != 0) begin: rx_no_fifo
    assign rx_data_s0 = phy_rx_data_s0;
    assign rx_data_s1 = phy_rx_data_s1;
    assign rx_data_s2 = phy_rx_data_s2;
    assign rx_data_s3 = phy_rx_data_s3;
    assign rx_data_valid = cfg_port_enable;
  end else begin
    assign rx_data_s0 = 12'h000;
    assign rx_data_s1 = 12'h000;
    assign rx_data_s2 = 12'h000;
    assign rx_data_s3 = 12'h000;
    assign rx_data_valid = 1'b0;
  end
endgenerate

////////////////////////////////////////////////////////////////////////////////
// Configuration & Reset logic

assign phy_lml_tmode = ~cfg_port_enable || ~cfg_port_tx;
assign phy_lml_txnrx_out = cfg_port_tx;
assign phy_lml_inportdis = ~cfg_port_enable || cfg_port_tx;
assign phy_lml_fclk_tmode = ~cfg_port_enable || ((IN_MODE != 2 && IN_MODE != 50) || cfg_port_rxfclk_dis) && ~cfg_port_tx || (OUT_MODE == 0) && cfg_port_tx;

assign phy_lml_termdis = cfg_port_rxterm_dis;

generate
  if (IN_MODE != 0) begin: rx_reset
    (* ASYNC_REG = "TRUE" *) reg phy_rx_reset_m_div;
    (* ASYNC_REG = "TRUE" *) reg phy_rx_reset_s_div;

    // Async reset and sync clear
    always @(posedge phy_rx_data_clk_div or negedge cfg_port_enable)
    begin
      if (~cfg_port_enable) begin
        phy_rx_reset_m_div <= 1'b1;
        phy_rx_reset_s_div <= 1'b1;
      end else begin
        phy_rx_reset_s_div <= phy_rx_reset_m_div;
        phy_rx_reset_m_div <= 1'b0;
      end
    end
    assign phy_rx_reset_clkdiv = phy_rx_reset_s_div;

    if ((IRX_IQSEL_PHASE != 0) && (IN_MODE == 2 || IN_MODE == 50)) begin
      (* ASYNC_REG = "TRUE" *) reg phy_rx_iqsel_reset_m_div;
      (* ASYNC_REG = "TRUE" *) reg phy_rx_iqsel_reset_s_div;
      always @(posedge phy_rx_iqsel_clk_div or negedge cfg_port_enable)
      begin
        if (~cfg_port_enable) begin
          phy_rx_iqsel_reset_m_div <= 1'b1;
          phy_rx_iqsel_reset_s_div <= 1'b1;
        end else begin
          phy_rx_iqsel_reset_s_div <= phy_rx_iqsel_reset_m_div;
          phy_rx_iqsel_reset_m_div <= 1'b0;
        end
      end
      assign phy_rx_iqsel_reset_clkdiv = phy_rx_iqsel_reset_s_div;
    end else begin
      assign phy_rx_iqsel_reset_clkdiv = phy_rx_reset_clkdiv;
    end
  end else begin
    assign phy_rx_reset_clkdiv = 1'b1;
    assign phy_rx_iqsel_reset_clkdiv = 1'b1;
  end
endgenerate

generate
  if (OUT_MODE != 0) begin: tx_reset
    (* ASYNC_REG = "TRUE" *) reg phy_tx_reset_m_div;
    (* ASYNC_REG = "TRUE" *) reg phy_tx_reset_s_div;

    // Async reset and sync clear
    always @(posedge phy_tx_data_clk_div or negedge cfg_port_enable)
    begin
      if (~cfg_port_enable) begin
        phy_tx_reset_m_div <= 1'b1;
        phy_tx_reset_s_div <= 1'b1;
      end else begin
        phy_tx_reset_s_div <= phy_tx_reset_m_div;
        phy_tx_reset_m_div <= 1'b0;
      end
    end
    assign phy_tx_reset_clkdiv = phy_tx_reset_s_div;
  end else begin
    assign phy_tx_reset_clkdiv = 1'b1;
  end
endgenerate

generate
  if (USE_IDELAY != 0 && IN_MODE != 0) begin: idelay_reset
    (* ASYNC_REG = "TRUE" *) reg phy_idelay_reset_m;
    (* ASYNC_REG = "TRUE" *) reg phy_idelay_reset_s;

    always @(posedge idelay_refclk or negedge cfg_port_enable)
    begin
      if (~cfg_port_enable) begin
        phy_idelay_reset_m <= 1'b1;
        phy_idelay_reset_s <= 1'b1;
      end else begin
        phy_idelay_reset_s <= phy_idelay_reset_m;
        phy_idelay_reset_m <= 1'b0;
      end
    end
    assign idelay_rst = phy_idelay_reset_s;
  end else begin
    assign idelay_rst = 1'b1;
  end
endgenerate

generate
  if (OUT_MODE == 2 || IN_MODE == 2 || IN_MODE == 50) begin: fclk_reset
    (* ASYNC_REG = "TRUE" *) reg phy_fclk_reset_m;
    (* ASYNC_REG = "TRUE" *) reg phy_fclk_reset_s;

`ifdef OSERDESE2_FCLK
    wire r_phy_fclk = phy_fclk_clk_div;
`else
    wire r_phy_fclk = phy_fclk_clk;
`endif
    always @(posedge r_phy_fclk or negedge cfg_port_enable)
    begin
      if (~cfg_port_enable) begin
        phy_fclk_reset_m <= 1'b1;
        phy_fclk_reset_s <= 1'b1;
      end else begin
        phy_fclk_reset_s <= phy_fclk_reset_m;
        phy_fclk_reset_m <= 1'b0;
      end
    end
    assign phy_fclk_reset = phy_fclk_reset_s;
  end else begin
    assign phy_fclk_reset = 1'b0; //TODO
  end
endgenerate

assign phy_tx_ce = 1'b1;
assign phy_rx_ce1 = 1'b1;
assign phy_rx_ce2 = 1'b1;


endmodule
