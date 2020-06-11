//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module dma_tx_sm #(
    parameter TS_BITS             = 30,
    parameter BUFFER_SIZE_TX_BITS = 17,
    parameter BUFFER_BUS_ADDRESS  = 32,
    parameter MAX_BURST_BITS      = 12,
    parameter LOW_ADDDR_BITS      = 14,
    parameter REQ_TAG_BITS        = 5
)(
    input                      mclk,
    output                     arst,
    output reg                 mode_siso,
    output reg                 mode_repeat,
    output reg [2:0]           mode_interp,
    input [1:0]                debug_fe_state,
    input [LOW_ADDDR_BITS-1:0] debug_rd_addr,

    input                      ts_rd_addr_inc,
    input [TS_BITS-1:0]        ts_rd_addr_late_samples,

    input                      ts_rd_addr_processed_inc,
    output                     ts_rd_valid,   // Valid start time & No of samples
    output [TS_BITS-1:0]       ts_rd_start,
    output [LOW_ADDDR_BITS-1:0]ts_rd_samples,
    input [TS_BITS-1:0]        ts_current,

    output                     out_rd_rst,
    output                     out_rd_clk,
    input [LOW_ADDDR_BITS:4]   out_rd_addr,

    // Maximum request len in QWords
    input  [2:0]               cfg_max_req_sz,

    // UL
    input                     s_ul_clk,
    input                     s_ul_aresetn,

    // UL Write channel
    input [7:0]               s_ul_waddr,  //1 KB space
    input [31:0]              s_ul_wdata,
    input                     s_ul_wvalid,
    output                    s_ul_wready,

    // Control
    input [7:0]               axis_control_data,
    input                     axis_control_valid,
    output                    axis_control_ready,

    // Burst Iface for configuration
    input [MAX_BURST_BITS-1+32:0] axis_burst_data,
    input                         axis_burst_valid,
    output                        axis_burst_ready,

    // Request & notify
    output reg                             ul_ml_rvalid,
    input                                  ul_ml_rready,
    output reg [BUFFER_SIZE_TX_BITS-1:3]   ul_ml_rlocaddr,
    output reg [BUFFER_BUS_ADDRESS-1:3]    ul_ml_rbusaddr,
    output reg [8:0]                       ul_ml_rlength,
    output reg [REQ_TAG_BITS-1:0]          ul_ml_rtag,

    input                     ul_ml_tvalid,
    output                    ul_ml_tready,
    input [REQ_TAG_BITS-1:0]  ul_ml_ttag,

    // Output data readback stream
    output [31:0]             axis_stat_data,
    output                    axis_stat_valid,
    input                     axis_stat_ready,

    // Output data readback stream
    output [31:0]             axis_stat_m_data,
    output                    axis_stat_m_valid,
    input                     axis_stat_m_ready,

    // Output data readback stream
    output [31:0]             axis_stat_ts_data,
    output                    axis_stat_ts_valid,
    input                     axis_stat_ts_ready,

    // Output data readback stream
    output [31:0]             axis_stat_cpl_data,
    output                    axis_stat_cpl_valid,
    input                     axis_stat_cpl_ready,

    output                    txdma_active,

    // Notification (LED)
    output                    tx_running,

    input                     int_ready,
    output reg                int_valid
);

assign out_rd_clk = s_ul_clk;

`include "xtrxll_regs.vh"

assign axis_stat_cpl_valid = 1'b1;

assign axis_control_ready = 1'b1;

assign axis_burst_ready = 1'b1;

// UL configuration space
assign s_ul_wready = 1'b1;

// DMA static configuration (isn't changing when DMA is active)
wire          dma_config_s_ul_wvalid = (s_ul_waddr[7:6] == 2'b00) && s_ul_wvalid;

// Config
//  20bit DMA buffer addr
wire          dma_en;

wire [BUFFER_BUS_ADDRESS-1:12]  dma_addr_out;
wire [4:0]                      dma_bufno;

dma_config dma_config(
   .s_ul_clk(s_ul_clk),

    // UL Write channel
   .s_ul_waddr(s_ul_waddr[4:0]),
   .s_ul_wdata(s_ul_wdata),
   .s_ul_wvalid(dma_config_s_ul_wvalid),

    // Control IF
   .dma_en(dma_en),
   .dma_bufno(dma_bufno),
   .dma_addr_out(dma_addr_out),
   .dma_buflen_out()
);

wire [TS_BITS-1:0]         current_burst_ts;
wire [MAX_BURST_BITS-1:0]  current_burst_samples_oldfmt; // 0 - means 4096 samples
wire [MAX_BURST_BITS-1:0]  current_burst_samples = current_burst_samples_oldfmt - 1'b1;

wire [4:0]         dma_buf_cfg;

wire [MAX_BURST_BITS-1:0]  axis_mod_samples = axis_burst_data[MAX_BURST_BITS-1+32:0+32];

ram32xsdp #(.WIDTH(MAX_BURST_BITS)) dram_ts(
    .wclk(s_ul_clk),
    .we(axis_burst_ready && axis_burst_valid),
    .waddr(dma_buf_cfg),
    .datai(axis_mod_samples),
    .raddr(dma_bufno),
    .datao(current_burst_samples_oldfmt[MAX_BURST_BITS-1:0])
);

wire [4:0]                  ts_rd_addr;


ram32xsdp #(.WIDTH(TS_BITS)) dram_sps(
    .wclk(s_ul_clk),
    .we(axis_burst_ready && axis_burst_valid),
    .waddr(dma_buf_cfg),
    .datai(axis_burst_data[TS_BITS-1:0]),
    .raddr(ts_rd_addr),
    .datao(current_burst_ts)
);

wire       fifo_reset_mclk2;
reg        axis_rx_disable;
wire [5:0] outnum_cleared;

cross_counter #(
   .WIDTH(6),
   .GRAY_BITS(4)
) prev_outnum(
   .inrst(fifo_reset_mclk2), //axis_rx_disable
   .inclk(mclk),
   .incmdvalid(ts_rd_addr_processed_inc),
   .incmdinc(1'b1),
   .incnt(),

   .outrst(axis_rx_disable),
   .outclk(s_ul_clk),
   .outcnt(outnum_cleared)
);

reg       reset_bufqueue;
reg [2:0] dma_state;

reg [5:0]  dma_bufno_reg;
assign     dma_bufno = dma_bufno_reg[4:0];

reg [5:0]  dma_bufno_written_reg;
assign dma_buf_cfg = dma_bufno_written_reg[4:0];

reg        dma_bufno_ready;

wire [7:0] dma_stat;
wire [5:0] filling_bn_uclk;

assign axis_stat_valid = 1'b1;
assign axis_stat_data = {filling_bn_uclk[5:4], dma_bufno_written_reg,  // Written by user
                         filling_bn_uclk[3:2], outnum_cleared,         // Sent out to air
                         filling_bn_uclk[1:0], dma_bufno_reg,          // Requested by DMA engine
                         dma_stat};

always @(posedge s_ul_clk) begin
  if (reset_bufqueue) begin
    dma_bufno_written_reg <= 6'b0;
  end else if (axis_burst_ready && axis_burst_valid) begin
    dma_bufno_written_reg <= dma_bufno_written_reg + 1'b1;
  end
end

wire [5:0] bufno_wr_avail = dma_bufno_written_reg - dma_bufno_reg - 1'b1;
always @(posedge s_ul_clk) begin
  if (dma_state == 0) begin
    dma_bufno_ready <= 1'b0;
  end else begin
    dma_bufno_ready <= ~bufno_wr_avail[5];
  end
end


reg  fifo_reset;

sync_reg #(.ASYNC_RESET(1)) fifo_reset_mclk(
  .clk(mclk),
  .rst(~s_ul_aresetn),
  .in(fifo_reset),
  .out(fifo_reset_mclk2)
);

assign arst       = fifo_reset_mclk2;
assign out_rd_rst = fifo_reset;

wire  [LOW_ADDDR_BITS-1:0]  ts_current_burst_samples;


// FOR DEBUG & VALIDATION REMOVE IT!!!
ram32xsdp #(.WIDTH(MAX_BURST_BITS)) dram_ts_samples(
    .wclk(s_ul_clk),
    .we(axis_burst_ready && axis_burst_valid),
    .waddr(dma_buf_cfg),
    .datai(axis_mod_samples),
    .raddr(ts_rd_addr),
    .datao(ts_current_burst_samples[MAX_BURST_BITS-1:0])
);

assign ts_current_burst_samples[LOW_ADDDR_BITS-1:MAX_BURST_BITS] =
	(ts_current_burst_samples[MAX_BURST_BITS-1:0] == 0) ? 1 : 0;

assign ts_rd_start = current_burst_ts;
assign ts_rd_samples = ts_current_burst_samples;

assign axis_stat_ts_data = ts_current;
assign axis_stat_ts_valid = 1'b1;

reg [15:0] delayed_bursts;
reg  [TS_BITS-1:0]         ts_rd_addr_late_samples_reg;
reg                        ts_rd_addr_late_samples_reg_valid;

localparam SAMPLES_ON_TIME = 2;

reg [19:0] last_late_samples;

always @(posedge mclk) begin
  if (fifo_reset_mclk2) begin
    delayed_bursts <= 0;
    ts_rd_addr_late_samples_reg       <= 0;
    ts_rd_addr_late_samples_reg_valid <= 1'b0;
    last_late_samples <= 0;
  end else begin
    if (ts_rd_addr_inc) begin
      ts_rd_addr_late_samples_reg       <= ts_rd_addr_late_samples;
      ts_rd_addr_late_samples_reg_valid <= 1'b1;
    end else begin
      ts_rd_addr_late_samples_reg_valid <= 1'b0;
    end

    if (ts_rd_addr_late_samples_reg_valid) begin
      if (ts_rd_addr_late_samples_reg != SAMPLES_ON_TIME) begin
        delayed_bursts <= delayed_bursts + 1'b1;
        last_late_samples <= ts_rd_addr_late_samples_reg;
      end
    end
  end
end

localparam ST_IDLE            = 0;
localparam ST_WAIT_DMA_BUFFER = 1;
localparam ST_CHECK_LEN       = 2;
localparam ST_UPDATE_ADDR     = 3;
localparam ST_READ_REQ_BUFFER = 4;
localparam ST_NEXT_BUFFER     = 5;
localparam ST_NEXT_BUFFER_WAIT= 6;
localparam ST_MODE_GENERATOR  = 7;



reg                      pcie_tag_latch;
reg [REQ_TAG_BITS-1:0]   pcie_tag;             // requested TAG

wire                     pcie_rtag_rd_latch;
wire [REQ_TAG_BITS-1:0]  pcie_rtag_rd;         // cpld TAG


assign tx_running = ~fifo_reset_mclk2;

reg                         buffer_burst_req_last; //Set when we request last transfer in the burst
reg  [LOW_ADDDR_BITS:0]     buffer_burst_req_addr; // With extra bit for overflow detection

// TODO: update this value
localparam TAG_ADDR_BUFFNO_ARRAY_WIDTH = 5;
wire [TAG_ADDR_BUFFNO_ARRAY_WIDTH-1:0] tag_in = dma_bufno;
wire [TAG_ADDR_BUFFNO_ARRAY_WIDTH-1:0] tag_out;
wire [4:0]                  buffer_burst_bufno        = tag_out[5-1:0];
ram32xsdp #(.WIDTH(TAG_ADDR_BUFFNO_ARRAY_WIDTH)) tag_waddr(
    .wclk(s_ul_clk),
    .we(pcie_tag_latch),
    .waddr(pcie_tag),
    .datai(tag_in),
    .raddr(pcie_rtag_rd),
    .datao(tag_out)
);

//
// TAG:     BUF_NO [4:0]
// BUF_NO:  IDXes in FLY [7:0]
//   -> BUF_NO[v_nxt] == 0 -> make buffer available

wire set_buffer_ready;
reg  set_buffer_valid;

// When buffer is filled and ready for TX
wire      inc_buf_filled_num;

assign ul_ml_tready = 1'b1;

reg [MAX_BURST_BITS-1+3:3]  burst_len_qw;      // Burst len in QWORDs 64-bit words
wire [MAX_BURST_BITS-1+3:7] bufcnts = (burst_len_qw[MAX_BURST_BITS-1+3:7] >> cfg_max_req_sz);

tx_fill_parts #(.WIDTH(MAX_BURST_BITS+1-4)) buffer_fills(
    .reset(axis_rx_disable),
    .s_ul_clk(s_ul_clk),

    .incb_valid(set_buffer_valid),
    .incb_ready(set_buffer_ready),
    .incb_size(bufcnts + 12'b1),
    .incb_idx(dma_bufno),

    .decb_valid(pcie_rtag_rd_latch),
    .decb_size(1'b1),
    .decb_idx(buffer_burst_bufno),

    .cur_buf_num(filling_bn_uclk[4:0]),
    .inc_buf(inc_buf_filled_num)
);

reg fifo_dma_en;
reg [3:0] fifo_addr_full; // fullness of buffer
reg [3:0] fifo_min_space;

assign dma_en = fifo_dma_en;

wire [LOW_ADDDR_BITS:4]   out_rd_addr_diff = buffer_burst_req_addr[LOW_ADDDR_BITS:4] - out_rd_addr;
// Buffer overrun detector
always @(posedge s_ul_clk) begin
  if (~fifo_dma_en) begin
    fifo_addr_full   <= 4'b0;
    fifo_min_space   <= 0;
  end else begin
    fifo_addr_full   <= out_rd_addr_diff[LOW_ADDDR_BITS:LOW_ADDDR_BITS-1-2];

    if (axis_stat_cpl_ready) begin
      fifo_min_space <= fifo_addr_full;
    end else if (fifo_min_space > fifo_addr_full) begin
      fifo_min_space <= fifo_addr_full;
    end
  end
end

reg [REQ_TAG_BITS:0] reset_idx;

wire tag_alloc_ready = reset_idx[REQ_TAG_BITS];
wire [REQ_TAG_BITS-1:0] tag_free_data  = pcie_rtag_rd;
wire                    tag_free_valid = pcie_rtag_rd_latch;

wire [REQ_TAG_BITS-1:0] fifo_in_data = (tag_alloc_ready) ? tag_free_data : reset_idx[REQ_TAG_BITS-1:0];
wire                    fifo_in_valid = (tag_alloc_ready) ? tag_free_valid : 1'b1;

wire [REQ_TAG_BITS-1:0] tag_free_num;
wire                    can_request_nxt_tlp;
wire [REQ_TAG_BITS-1:0] tag_fifo_used;

axis_fifo32 #(.WIDTH(REQ_TAG_BITS)) tag_alloc_queue (
  .clk(s_ul_clk),
  .axisrst(axis_rx_disable),

  .axis_rx_tdata(fifo_in_data),
  .axis_rx_tvalid(fifo_in_valid),
  .axis_rx_tready(),

  .axis_tx_tdata(tag_free_num),
  .axis_tx_tvalid(can_request_nxt_tlp),
  .axis_tx_tready(pcie_tag_latch),

  .fifo_used(tag_fifo_used),
  .fifo_empty()
);

always @(posedge s_ul_clk) begin
  if (axis_rx_disable) begin
    reset_idx <= 0;
  end else begin
    if (~tag_alloc_ready) begin
      reset_idx <= reset_idx + 1'b1;
    end
  end
end


wire [REQ_TAG_BITS-1:0] buffer_req_in_fly = tag_fifo_used;

reg [5:0] intr_outnum_cleared;
// Interrupt logic
always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    int_valid <= 1'b0;
    intr_outnum_cleared <= 0;
  end else begin
    if (int_valid && int_ready) begin
      int_valid           <= 1'b0;
      intr_outnum_cleared <= outnum_cleared;
    end else if (outnum_cleared != intr_outnum_cleared) begin
      int_valid           <= 1'b1;
    end
  end
end

// Request PCIe DMA addr
reg [BUFFER_BUS_ADDRESS-1:3] pcie_dma_addr;

wire [11:7] cfg_max_request_len =
  (cfg_max_req_sz == 3'b000) ? 5'b00000 :
  (cfg_max_req_sz == 3'b001) ? 5'b00001 :
  (cfg_max_req_sz == 3'b010) ? 5'b00011 :
  (cfg_max_req_sz == 3'b011) ? 5'b00111 :
  (cfg_max_req_sz == 3'b100) ? 5'b01111 : 5'b11111;

reg [11:3]                   pcie_len_req_qw;   // Current request for Read Req
wire [11:3]                  cfg_max_request_len_qw = {cfg_max_request_len, 4'b1111 };

wire fifo_buffer_ready = ~out_rd_addr_diff[LOW_ADDDR_BITS];

// Requester process
always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    dma_state              <= ST_IDLE;
    fifo_reset             <= 1'b1;
    pcie_tag               <= 4'b0;
    ul_ml_rvalid           <= 1'b0;
    axis_rx_disable        <= 1'b1;
    buffer_burst_req_last  <= 1'b0;
    dma_bufno_reg          <=    0;
    pcie_tag_latch         <=    0;
    set_buffer_valid       <= 1'b0;

    buffer_burst_req_addr  <= 0;

    mode_interp            <= 0;
    reset_bufqueue         <= 1'b1;
  end else begin
    case (dma_state)
      ST_WAIT_DMA_BUFFER: begin
        // Start new buffer request only when buffer slot is available

        if (dma_bufno_ready) begin
            pcie_dma_addr        <= { dma_addr_out, 9'h00 };
            burst_len_qw         <= current_burst_samples;

            set_buffer_valid     <= 1'b1;
            dma_state            <= ST_CHECK_LEN;
        end
      end

      ST_CHECK_LEN: begin
        if (set_buffer_ready) begin
          pcie_len_req_qw       <= (burst_len_qw > cfg_max_request_len_qw) ? cfg_max_request_len_qw : burst_len_qw;
          buffer_burst_req_last <= (burst_len_qw > cfg_max_request_len_qw) ? 1'b0: 1'b1;

          dma_state             <= ST_UPDATE_ADDR;
          set_buffer_valid      <= 1'b0;
        end
      end

      ST_UPDATE_ADDR: begin
        ul_ml_rlength          <= pcie_len_req_qw;
        ul_ml_rbusaddr         <= pcie_dma_addr;
        ul_ml_rlocaddr         <= buffer_burst_req_addr;

        dma_state              <= ST_READ_REQ_BUFFER;
        pcie_dma_addr          <= pcie_dma_addr + pcie_len_req_qw + 1'b1;
        burst_len_qw           <= burst_len_qw -  pcie_len_req_qw - 1'b1;

        buffer_burst_req_addr  <= buffer_burst_req_addr + pcie_len_req_qw + 1'b1;
      end

      ST_READ_REQ_BUFFER: begin
        if (can_request_nxt_tlp && fifo_buffer_ready) begin
          ul_ml_rvalid               <= 1'b1;
          pcie_tag_latch             <= 1'b1;
          pcie_tag                   <= tag_free_num[REQ_TAG_BITS-1:0];
          ul_ml_rtag                 <= tag_free_num[REQ_TAG_BITS-1:0];
          dma_state                  <= ST_NEXT_BUFFER;
        end
      end

      ST_NEXT_BUFFER: begin
        pcie_tag_latch <= 1'b0;

        if (ul_ml_rready) begin
          ul_ml_rvalid <= 1'b0;
        end

        if (~ul_ml_rvalid || ul_ml_rready) begin
          if (buffer_burst_req_last) begin
            dma_state         <= ST_NEXT_BUFFER_WAIT;
            dma_bufno_reg     <= dma_bufno_reg + 1'b1;
          end else begin
            dma_state         <= ST_CHECK_LEN;
          end
        end
      end

      // We need this buuble stage to settle dma_bufno_ready
      ST_NEXT_BUFFER_WAIT: begin
        dma_state      <= ST_WAIT_DMA_BUFFER;
      end
    endcase

    case (dma_state)
      ST_IDLE: begin
        if (axis_control_valid && (axis_control_data[1:0] != FMT_STOP)) begin

          if (~axis_control_data[GP_PORT_TXDMA_CTRL_MODE_REP]) begin
            fifo_dma_en   <= 1'b1;
            dma_state     <= ST_WAIT_DMA_BUFFER;
            fifo_reset    <= 1'b0;
          end else begin
            dma_state     <= ST_MODE_GENERATOR;
          end

          mode_siso        <= axis_control_data[GP_PORT_TXDMA_CTRL_MODE_SISO];
          mode_repeat      <= axis_control_data[GP_PORT_TXDMA_CTRL_MODE_REP];
          mode_interp      <= axis_control_data[GP_PORT_TXDMA_CTRL_MODE_INTER_OFF+2:GP_PORT_TXDMA_CTRL_MODE_INTER_OFF];

          axis_rx_disable <= 1'b0;
          reset_bufqueue  <= 1'b0;
        end else begin
          fifo_reset    <= 1'b1;
          fifo_dma_en   <= 1'b0;
          mode_repeat   <= 1'b0;
          mode_siso     <= 1'b0;
          axis_rx_disable <= 1'b1;

          pcie_tag               <= 0;
          ul_ml_rvalid           <= 1'b0;
          buffer_burst_req_last  <= 1'b0;
          dma_bufno_reg          <=    0;
          pcie_tag_latch         <=    0;
          buffer_burst_req_addr  <=    0;
          set_buffer_valid       <= 1'b0;
          reset_bufqueue         <= ~axis_control_data[GP_PORT_TXDMA_CTRL_RESET_BUFS];
        end
      end

      ST_MODE_GENERATOR: begin
        if (axis_control_ready && axis_control_valid) begin
          if (axis_control_data[1:0] != FMT_STOP) begin
            fifo_reset    <= 1'b0;
          end else begin
            dma_state     <= ST_IDLE;
          end
        end
      end

      default: begin
        if (axis_control_valid && axis_control_data[1:0] == FMT_STOP) begin
          dma_state       <= ST_IDLE;
        end
      end
    endcase
  end
end



// MCLK: Read timestamp ADDR register
reg [5:0] ts_rd_addr_reg;
assign    ts_rd_addr = ts_rd_addr_reg[4:0];

always @(posedge mclk or posedge axis_rx_disable) begin
  if (axis_rx_disable) begin
    ts_rd_addr_reg <= 6'b0;
  end else begin
    if (ts_rd_addr_inc) begin
      ts_rd_addr_reg <= ts_rd_addr_reg + 1;
    end
  end
end


wire [5:0] filling_buf_no; //Idx of filling buffer, it's not finished yet!

// Counter to report number of valid buffer to the other side of FIFO
cross_counter #(
   .WIDTH(6),
   .GRAY_BITS(4)
) filling_buf_cntr(
   .inrst(axis_rx_disable),
   .inclk(s_ul_clk),
   .incmdvalid(inc_buf_filled_num),
   .incmdinc(1'b1),
   .incnt(filling_bn_uclk),

   .outrst(fifo_reset_mclk2),
   .outclk(mclk),
   .outcnt(filling_buf_no)
);

reg ts_rd_valid_reg;
assign ts_rd_valid = ts_rd_valid_reg;

// MCLK: Numbers of filled DMA TX buffers in our RAM
wire [5:0] num_filled_buffers = (filling_buf_no - ts_rd_addr_reg - 1'b1);

always @(posedge mclk) begin
  ts_rd_valid_reg <= ~num_filled_buffers[5];
end

assign ul_ml_tready       = 1'b1;
assign pcie_rtag_rd       = ul_ml_ttag;
assign pcie_rtag_rd_latch = ul_ml_tvalid;


assign axis_stat_cpl_data = {
  last_late_samples, fifo_min_space[3:0], 3'b000, tag_fifo_used[4:0] };

assign txdma_active = axis_rx_disable;

//                    1b            4b                  3b
assign dma_stat = { fifo_reset , fifo_addr_full, dma_state };
assign axis_stat_m_valid = 1'b1;
assign axis_stat_m_data  = { delayed_bursts /*({buffer_burst_req_addr[LOW_ADDDR_BITS-2:0], 1'b0} - debug_rd_addr)*/, buffer_req_in_fly[1:0], debug_fe_state, filling_buf_no, ts_rd_addr_reg };
                        //2b                  //2b                // 12b
endmodule
