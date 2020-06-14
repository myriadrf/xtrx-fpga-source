//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module dma_rx_sm #(
    parameter BUFFER_SIZE_RX_BITS = 16,
    parameter BUFFER_BURST_BITS = 5,
    parameter BUFFER_BUS_ADDRESS = 32,
    parameter MEM_TAG = 5
)(
    input                     s_ul_clk,
    input                     s_ul_aresetn,

    // UL Write channel
    input [7:0]               s_ul_waddr,  //1 KB space
    input [31:0]              s_ul_wdata,
    input                     s_ul_wvalid,
    output                    s_ul_wready,

    // RXDMA control channel
    input [9:0]               axis_control_data,
    input                     axis_control_valid,
    output                    axis_control_ready,

    // Buffer confirmation channel
    // input [31:0]              axis_confirm_data,
    input                     axis_confirm_valid,
    output                    axis_confirm_ready,

    input                     ctrl_dntchk,
    input                     ctrl_intovfsep,

    // RXDMA stat output
    output [31:0]             axis_stat_data,
    output                    axis_stat_valid,
    input                     axis_stat_ready,

    // DATA Mover
    input                     cfg_max_payload_sz,


    // Bus data move request
    output reg                               ul_lm_rvalid,
    input                                    ul_lm_rready,
    output reg [BUFFER_SIZE_RX_BITS - 1:3]   ul_lm_rlocaddr,
    output reg [BUFFER_BUS_ADDRESS - 1:3]    ul_lm_rbusaddr,
    output reg [BUFFER_BURST_BITS - 1 + 3:3] ul_lm_rlength,
    output reg [MEM_TAG-1:0]                 ul_lm_rtag,

    // Bus data move confirmation
    input                                    ul_lm_tvalid,
    output                                   ul_lm_tready,
    input [MEM_TAG-1:0]                      ul_lm_ttag,

    // Interrupt Data (+OVF in mix mode)
    input              int_ready,
    output reg         int_valid,

    // Interrupt OVF (buffer overflow)
    input              intovf_ready,
    output reg         intovf_valid,

    // Writer stats (for overrun detection)
    input [2:0]        writer_pos,
    input              dma_resume_cmd,

    // RX Fronetend config
    output reg [1:0]                       fe_decim_rate,
    output reg [1:0]                       fe_fmt,
    output reg                             fe_siso_mode,
    output reg                             fe_enable,
    output reg                             fe_rst,
    output reg                             fe_stall
);

// Full size - 8 for delayed syncronization
localparam RING_BUF_OVERFLOW_MB = ((1 << (BUFFER_SIZE_RX_BITS-4)) - 16);
reg           dma_en;


// leave 12 bit counter for compattibility
wire [31:12]  dma_addr_out;
wire [15:4]   dma_buflen_out_old;

wire [4:0]    dma_bufno;

// DMA static configuration (isn't changing when DMA is active)
assign s_ul_wready = 1'b1;

dma_config dma_config(
   .s_ul_clk(s_ul_clk),

    // UL Write channel
   .s_ul_waddr(s_ul_waddr[4:0]),
   .s_ul_wdata(s_ul_wdata),
   .s_ul_wvalid(s_ul_wvalid && (s_ul_waddr[7:5] == 0)),

    // Control IF
   .dma_en(dma_en),
   .dma_bufno(dma_bufno),
   .dma_addr_out(dma_addr_out),
   .dma_buflen_out(dma_buflen_out_old)
);

reg         dma_buflen_huge;
reg  [23:4] dma_buflen_out_new;
wire [23:3] dma_buflen_out = { (dma_buflen_huge) ? dma_buflen_out_new : dma_buflen_out_old, 1'b1 };

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    dma_buflen_out_new  <= 0;
    dma_buflen_huge     <= 0;
  end else begin
    if (s_ul_wvalid && s_ul_wready && (s_ul_waddr[7:5] == 1 && s_ul_waddr[4:0] == 0)) begin
      dma_buflen_huge    <= s_ul_wdata[31];
      dma_buflen_out_new <= s_ul_wdata[19:0];
    end
  end
end

localparam POS_BITS = 3;

reg [BUFFER_SIZE_RX_BITS-1:4] ring_count;      // Amount of 128-bit data since start
reg [POS_BITS-1:0]            writer_pos_prev;
wire                          wrap_writer_pos = (writer_pos_prev > writer_pos);


wire[BUFFER_SIZE_RX_BITS-1:4]    ring_read_addr_mb = ul_lm_rlocaddr[BUFFER_SIZE_RX_BITS - 1:4];
reg [BUFFER_SIZE_RX_BITS-1:4]    ring_avail_words_mb;
reg                              ring_overflow;
reg                              ring_overflow_prev;
reg                              ring_enough_for_pcie;

wire [7:3] cfg_dma_max_pcie_transfer = (cfg_max_payload_sz == 0) ? 5'h0f : 5'h1f;

wire ring_overflow_sig = (ring_avail_words_mb > RING_BUF_OVERFLOW_MB);

always @(posedge s_ul_clk) begin
  if (~dma_en || fe_stall) begin
    writer_pos_prev      <= 0;

    ring_avail_words_mb  <= 0;

    ring_count           <= 0;
    ring_enough_for_pcie <= 0;
  end else begin
    ring_count[BUFFER_SIZE_RX_BITS-1:POS_BITS+4] <= ring_count[BUFFER_SIZE_RX_BITS-1:POS_BITS+4] + wrap_writer_pos;
    ring_count[POS_BITS-1+4:4]                   <= writer_pos;
    writer_pos_prev                              <= writer_pos;

    ring_avail_words_mb[BUFFER_SIZE_RX_BITS-1:4] <= ring_count[BUFFER_SIZE_RX_BITS-1:4] - ring_read_addr_mb[BUFFER_SIZE_RX_BITS-1:4];
    ring_enough_for_pcie                         <= (ring_avail_words_mb[BUFFER_SIZE_RX_BITS-1:4] > cfg_dma_max_pcie_transfer[7:4]);
  end
end

// Remaining data in current DMA buffer in 16-bytes
reg [23:3] dma_block_rem;

localparam DMA_IDLE            = 0;
localparam DMA_WAIT_BUFFER     = 1;
localparam DMA_REQ_TRANSFER    = 2;
localparam DMA_UPDATE_COUNTERS = 3;

reg [1:0]  dma_state;

reg reset_buf_len;
wire dma_next_buf;

reg [5:0] dma_bufno_read;
reg [5:0] dma_bufno_reg;
assign dma_bufno = dma_bufno_reg[4:0];

assign axis_confirm_ready = 1'b1;
always @(posedge s_ul_clk) begin
  if (dma_state == DMA_IDLE) begin
    dma_bufno_read   <= 5'b0;
    dma_bufno_reg    <= 5'b0;
  end else begin
    if (axis_confirm_valid) begin
      dma_bufno_read            <= dma_bufno_read + 1;
    end

    if (dma_next_buf) begin
      dma_bufno_reg             <= dma_bufno_reg + 1'b1;
    end
  end
end

wire [5:0] buf_write_ptr = dma_bufno_read - dma_bufno_reg - 1'b1;

reg dma_blk_ready;
always @(posedge s_ul_clk) begin
  dma_blk_ready <= buf_write_ptr[5];
end

reg int_ovf_sep = 0;

// Interrupt logic
always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    int_valid     <= 1'b0;
    intovf_valid  <= 1'b0;
  end else begin
    if (dma_next_buf || ~int_ovf_sep && ring_overflow && ~ring_overflow_prev) begin
      int_valid <= 1'b1;
    end else if (int_valid && int_ready) begin
      int_valid <= 1'b0;
    end

    if (int_ovf_sep && ring_overflow && ~ring_overflow_prev) begin
      intovf_valid <= 1'b1;
    end else if (intovf_valid && intovf_ready) begin
      intovf_valid <= 1'b0;
    end
  end
end

// UL Read data
assign axis_stat_valid = 1'b1;
assign axis_stat_data = {
/* 16bits */  ring_overflow, ring_enough_for_pcie, ring_avail_words_mb[BUFFER_SIZE_RX_BITS-1:BUFFER_SIZE_RX_BITS-12], dma_blk_ready, fe_enable,
/* 16bits */  fe_decim_rate, fe_fmt,  dma_bufno_read, dma_bufno_reg
};

// DMA control
wire [1:0] ctrl_fe_fmt          = axis_control_data[1:0];
wire [1:0] ctrl_fe_decim_rate   = axis_control_data[3:2];
wire       ctrl_fe_paused       = axis_control_data[4];
wire       ctrl_fe_reset        = axis_control_data[5];
wire       ctrl_fe_siso_mode    = axis_control_data[6];

wire start_rx = axis_control_ready && axis_control_valid && (ctrl_fe_fmt != 2'b0);
wire stop_rx  = axis_control_ready && axis_control_valid && (ctrl_fe_fmt == 2'b0);

assign axis_control_ready = (dma_state == DMA_IDLE || dma_state == DMA_WAIT_BUFFER);


always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    fe_rst <= 1'b1;
  end else if ( axis_control_valid ) begin
    fe_rst <= ctrl_fe_reset;
  end
end

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    ring_overflow      <= 1'b0;
    ring_overflow_prev <= 1'b0;
  end else if (dma_state == DMA_IDLE && start_rx) begin
    ring_overflow      <= 1'b0;
    ring_overflow_prev <= 1'b0;
  end else begin
    if (~ring_overflow)
      ring_overflow <= ring_overflow_sig;
    else if (/*dma_resume_cmd*/ ring_overflow && axis_stat_valid && axis_stat_ready) begin
      ring_overflow <= 1'b0; //Clear overflow flag on resume command
    end

    ring_overflow_prev <= ring_overflow;
  end
end

wire [24:3] dma_block_rem_next = {1'b0, dma_block_rem} - cfg_dma_max_pcie_transfer - 1'b1;
wire        dma_transfer_too_big = ~dma_block_rem_next[24];

reg        dont_check_overrun;
reg [1:0]  req_tag_valid;
reg [1:0]  req_trans_last;

wire [1:0] tag_id =
  (~req_tag_valid[0]) ? 2'b00 :
  (~req_tag_valid[1]) ? 2'b01 : 2'b10;
wire [0:0] tag_idx = tag_id[0];
wire tag_avaliable = ~tag_id[1];

assign ul_lm_tready = 1'b1;
assign dma_next_buf = ul_lm_tvalid && ul_lm_tready && req_trans_last[ul_lm_ttag[0]];

reg [1:0] re_valid;

// DMA control and PCIe data movement process
always @(posedge s_ul_clk) begin
  if ( ~s_ul_aresetn ) begin
    dma_state     <= DMA_IDLE;
    dma_en        <= 1'b0;

    fe_decim_rate <= 2'b0;
    fe_siso_mode  <= 1'b0;
    fe_fmt        <= 2'b0;
    fe_enable     <= 1'b0;
    fe_stall      <= 1'b0;

    dont_check_overrun <= 1'b0;
    req_tag_valid      <= 2'b00;

    ul_lm_rvalid       <= 1'b0;

    re_valid           <= 2'b00;
  end else begin

  if (ring_overflow && ~dma_resume_cmd) begin
    fe_stall <= 1'b1;
  end

  if (ul_lm_tvalid && ul_lm_tready) begin
    req_tag_valid[ul_lm_ttag[0]] <= 1'b0;
  end

  re_valid <= { re_valid[0], 1'b1 };

  case (dma_state)
    DMA_IDLE: begin
      if (start_rx) begin
        dma_en          <= 1'b1;
        dma_state       <= DMA_WAIT_BUFFER;
        reset_buf_len   <= 1'b1;

        fe_siso_mode    <= ctrl_fe_siso_mode;
        fe_decim_rate   <= ctrl_fe_decim_rate;
        fe_fmt          <= ctrl_fe_fmt;
        fe_enable       <= 1'b1;
        fe_stall        <= ctrl_fe_paused;
        dont_check_overrun <= ctrl_dntchk;
        int_ovf_sep        <= ctrl_intovfsep;
      end else begin
        fe_enable         <= 1'b0;
        dma_en            <= 1'b0;
        ul_lm_rlocaddr    <= 0;
      end
    end

    DMA_WAIT_BUFFER: begin
      if (stop_rx /*|| fe_rst*/) begin
         dma_state <= DMA_IDLE;
         dma_en    <= 1'b0;
         fe_fmt    <= 2'b0;
         //fe_stall  <= 1'b0;
      end else if (ring_overflow || fe_stall) begin
         ul_lm_rlocaddr <= 0;
         re_valid       <= 2'b00;

         // Wait for recovery
         if (dma_resume_cmd) begin
           fe_stall <= 1'b0;
         end else begin
           fe_stall <= 1'b1;
         end
      end else if ((dma_blk_ready || dont_check_overrun) && ring_enough_for_pcie && re_valid[1]) begin
         // Update DMA remaining block only when next buffer is requested
         if (reset_buf_len) begin
            dma_block_rem       <= dma_buflen_out;
            reset_buf_len       <= 1'b0;

            ul_lm_rbusaddr      <= { dma_addr_out[BUFFER_BUS_ADDRESS - 1:12], 9'h000 };
         end

         dma_state     <= DMA_REQ_TRANSFER;
      end
    end

    DMA_REQ_TRANSFER: begin
      if (tag_avaliable) begin
        if (dma_transfer_too_big) begin
           ul_lm_rlength <= cfg_dma_max_pcie_transfer;
        end else begin
           ul_lm_rlength <= dma_block_rem;
        end

        ul_lm_rvalid            <= 1'b1;
        ul_lm_rtag              <= tag_idx;
        req_tag_valid[tag_idx]  <= 1'b1;
        req_trans_last[tag_idx] <= ~dma_transfer_too_big;
        dma_state               <= DMA_UPDATE_COUNTERS;
      end
    end

    DMA_UPDATE_COUNTERS: begin
      if (ul_lm_rvalid && ul_lm_rready) begin
        ul_lm_rvalid         <= 1'b0;
        ul_lm_rlocaddr       <= ul_lm_rlocaddr + ul_lm_rlength + 1'b1;
        re_valid             <= 2'b00;
        dma_block_rem        <= dma_block_rem_next;
        reset_buf_len        <= ~dma_transfer_too_big;

        ul_lm_rbusaddr       <= ul_lm_rbusaddr + ul_lm_rlength + 1'b1;

        dma_state            <= DMA_WAIT_BUFFER;
      end
    end

  endcase
  end
end

endmodule
