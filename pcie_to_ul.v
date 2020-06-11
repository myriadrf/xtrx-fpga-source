//
// Copyright (c) 2016-2019 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// PCIe to master UL
//
// NOTICE: Read around Write isn't supported right now

module pcie_to_ul #(
    parameter ADDR_WIDTH = 10,
    parameter HOST_LE = 1
)(
    input             clk,
    input             rst_n,

    // Configuration
    input  [15:0] cfg_completer_id,

    // AXIs PCIe RX
    input  [63:0] m_axis_rx_tdata,
    input  [7:0]  m_axis_rx_tkeep,
    input         m_axis_rx_tlast,
    input         m_axis_rx_tvalid,
    output        m_axis_rx_tready,

    // AXIs PCIe TX
    input              s_axis_tx_tready,
    output  reg [63:0] s_axis_tx_tdata,
    output  reg [7:0]  s_axis_tx_tkeep,
    output  reg        s_axis_tx_tlast,
    output  reg        s_axis_tx_tvalid,

    /////////////////////////////////////
    // UL Write channel
    output reg [ADDR_WIDTH - 1:0]       m_ul_waddr,
    output [31:0]                       m_ul_wdata,
    output reg                          m_ul_wvalid,
    input                               m_ul_wready,

    // AXI Read address channel
    output reg [ADDR_WIDTH - 1:0]       m_ul_araddr,
    output reg                          m_ul_arvalid,
    input                               m_ul_arready,

    // AXI Read data channel signals
    input [31:0]                        m_ul_rdata,
    input                               m_ul_rvalid,
    output reg                          m_ul_rready
);

reg [31:0] m_ul_wdata_t;
reg [31:0] readdata_t;

wire [31:0] readdata;

genvar i;
generate
  if (HOST_LE == 1) begin
    assign readdata = readdata_t;
    assign m_ul_wdata = m_ul_wdata_t;
  end else begin
    for (i = 0; i < 4; i=i+1) begin
      assign readdata[(i+1)*8-1:i*8]   = readdata_t[(4-i)*8-1:(3-i)*8];
      assign m_ul_wdata[(i+1)*8-1:i*8] = m_ul_wdata_t[(4-i)*8-1:(3-i)*8];
    end
  end
endgenerate


// Memory
localparam MEM_RD32_FMT_TYPE =      7'b00_00000;   // 3DW
localparam MEM_RD64_FMT_TYPE =      7'b01_00000;   // 4DW

localparam MEM_RD32_LOCK_FMT_TYPE = 7'b00_00001;   // 3DW
localparam MEM_RD64_LOCK_FMT_TYPE = 7'b01_00001;   // 4DW

localparam MEM_WR32_FMT_TYPE =      7'b10_00000;   // 3DW + data
localparam MEM_WR64_FMT_TYPE =      7'b11_00000;   // 4DW + data

// IO
localparam IO_RD32_FMT_TYPE  =      7'b00_00010;   // 3DW
localparam IO_WR32_FMT_TYPE  =      7'b10_00010;   // 3DW + data

// Config Type 0/1
localparam CFGT0_RD_FMT_TYPE =      7'b00_00100;   // 3DW
localparam CFGT0_WR_FMT_TYPE =      7'b10_00100;   // 3DW + data
localparam CFGT1_RD_FMT_TYPE =      7'b00_00101;   // 3DW
localparam CFGT1_WR_FMT_TYPE =      7'b10_00101;   // 3DW + data

// Message
localparam MSG_FMT_TYPE  =          7'b00_10xxx;   // 4DW
localparam MSG_DATA_FMT_TYPE  =     7'b10_10xxx;   // 4DW + data

// Completion
localparam CPL_FMT_TYPE =           7'b00_01010;   // 3DW
localparam CPL_DATA_FMT_TYPE =      7'b10_01010;   // 3DW + data
localparam CPL_LOCK_FMT_TYPE =      7'b00_01011;   // 3DW
localparam CPL_LOCK_DATA_FMT_TYPE = 7'b10_01011;   // 3DW + data


wire   sop;         // First TLP QWORD

reg [3:0]   state;
localparam STATE_RESET      = 0; // Initial TLP header parse
localparam STATE_WR32_AD    = 1; // Address & Data on UL
localparam STATE_WR32_D0    = 2; // Next data
localparam STATE_WR32_D1    = 3; // Next data 2

localparam STATE_RD32_A     = 4;
localparam STATE_RD32_STALL = 5;
localparam STATE_RD32_NF    = 6; // wait for notification
localparam STATE_RD32_R1    = 7;
localparam STATE_RD32_R2    = 8;

localparam STATE_SKIP       = 9;

localparam STATE_RD32_ANS   = 10;
localparam STATE_RD32_RN    = 11;
localparam STATE_RD32_ANS2  = 12;
localparam STATE_RD32_RN2   = 13;


reg [15:0] pcie_req_id;
reg [7:0]  pcie_tag;
reg [2:0]  pcie_tc;
reg [1:0]  pcie_attr;
reg [6:2]  pcie_low_addr; // For Completion

reg [7:0]  pcie_len_dw; // max 128 DW -> 512 bytes

  //
  // req_id[63:48] | tag[47:40] | ldwbe[39:36] fdwbe[35:32] || # fmt_type[30:24] | # tc[22:20] #### | td[15] ep[14] attr[13:12] ## length[9:0]
  //             data[63:32]                                ||      addr[31:2]                                                             ##


// only valid when SOP is asserted
wire [9:0] tlp_length = m_axis_rx_tdata[9:0];
//      reserved        m_axis_rx_tdata[11:10]
wire [1:0] tlp_attr   = m_axis_rx_tdata[13:12];
wire       tlp_ep     = m_axis_rx_tdata[14];
wire       tlp_dp     = m_axis_rx_tdata[15];
//      reserved        m_axis_rx_tdata[19:16]
wire [2:0] tlp_tc     = m_axis_rx_tdata[22:20];
//      reserved        m_axis_rx_tdata[23]
wire [4:0] tlp_type   = m_axis_rx_tdata[28:24];
wire [1:0] tlp_fmt    = m_axis_rx_tdata[30:29];
//      reserved        m_axis_rx_tdata[31]
wire [3:0] tlp_ldwbe  = m_axis_rx_tdata[39:36];
wire [3:0] tlp_fdwbe  = m_axis_rx_tdata[35:32];


assign m_axis_rx_tready = (state == STATE_RESET)  ||
                          (state == STATE_RD32_A) ||
                          (state == STATE_SKIP)   ||
                          (state == STATE_WR32_AD && (~m_ul_wvalid || m_ul_wready)) ||
                          ((state == STATE_WR32_D0 && ~m_axis_rx_tkeep[7]) || state == STATE_WR32_D1) && m_ul_wready;

always @( posedge clk ) begin
  if (!rst_n) begin
    s_axis_tx_tvalid <= 1'b0;
    s_axis_tx_tlast  <= 1'b0;
    s_axis_tx_tkeep  <= 8'b0;

    m_ul_wvalid      <= 1'b0;
    m_ul_arvalid     <= 1'b0;
    m_ul_rready      <= 1'b0;

    state            <= STATE_RESET;
  end else begin
    if (m_ul_wready && m_ul_wvalid && (state != STATE_WR32_AD) && (state != STATE_WR32_D0) &&  (state != STATE_WR32_D1)) begin
      m_ul_wvalid <= 1'b0;
    end

    case (state)
    STATE_RESET: begin
      if (/*m_axis_rx_tready &&*/ m_axis_rx_tvalid) begin
        case ({tlp_fmt,tlp_type})
        MEM_RD32_FMT_TYPE : begin

          if (/* tlp_length == 10'h1 && */ // 1-DW
                      tlp_ep     == 1'b0 &&   // Data isn't poisoned
                      tlp_fdwbe  == 4'hF)     // 32-bit transfer
            state <= STATE_RD32_A;
          else
            state <= STATE_SKIP;

          pcie_req_id <= m_axis_rx_tdata[63:48];
          pcie_tag    <= m_axis_rx_tdata[47:40];
          pcie_tc     <= tlp_tc;
          pcie_attr   <= tlp_attr;
          pcie_len_dw <= tlp_length[7:0]; // holds up to 128DW == 512 Bytes
        end

        MEM_WR32_FMT_TYPE : begin
                  // we accept only 32 bit 1-DW command only
          if (/* tlp_length == 10'h1 && */  // 1-DW
                      tlp_ep     == 1'b0 &&   // Data isn't poisoned
                      tlp_fdwbe  == 4'hF)     // 32-bit transfer
            state <= STATE_WR32_AD;
          else
            state <= STATE_SKIP;
        end

        default: begin
          state <= STATE_SKIP;
        end
        endcase
      end
    end // STATE_RESET

    // WRITE STATES
    STATE_WR32_AD: begin
      if (/*m_axis_rx_tready && */ (~m_ul_wvalid || m_ul_wready) && m_axis_rx_tvalid) begin
        m_ul_wdata_t     <= m_axis_rx_tdata[63:32];
        m_ul_waddr       <= m_axis_rx_tdata[ADDR_WIDTH + 1:2];
        m_ul_wvalid      <= 1'b1;

        if (m_axis_rx_tlast) begin
          state             <= STATE_RESET;
        end else begin
          state             <= STATE_WR32_D0;
        end
      end else if (m_ul_wready && m_ul_wvalid) begin
        m_ul_wvalid      <= 1'b0;
      end
    end

    STATE_WR32_D0: begin
      if (/*m_axis_rx_tready && */ m_ul_wready && m_axis_rx_tvalid) begin
        m_ul_waddr       <= m_ul_waddr + 1'b1;
        m_ul_wdata_t     <= m_axis_rx_tdata[31:0];
        m_ul_wvalid      <= 1'b1;

        if (m_axis_rx_tlast && ~m_axis_rx_tkeep[7]) begin
          state            <= STATE_RESET;
        end else begin
          state            <= STATE_WR32_D1;
        end
      end else if (m_ul_wready && m_ul_wvalid) begin
        m_ul_wvalid      <= 1'b0;
      end
    end

    STATE_WR32_D1: begin
      if (/*m_axis_rx_tready && */ m_ul_wready && m_axis_rx_tvalid) begin
        m_ul_waddr       <= m_ul_waddr + 1'b1;
        m_ul_wdata_t     <= m_axis_rx_tdata[63:32];
        m_ul_wvalid      <= 1'b1;

        if (m_axis_rx_tlast) begin
          state            <= STATE_RESET;
        end else begin
          state            <= STATE_WR32_D0;
        end
      end else if (m_ul_wready && m_ul_wvalid) begin
        m_ul_wvalid      <= 1'b0;
      end
    end

    STATE_RD32_A: begin
      if (/*m_axis_rx_tready &&*/ m_axis_rx_tvalid) begin
        m_ul_araddr   <= m_axis_rx_tdata[ADDR_WIDTH + 1:2];
        pcie_low_addr <= m_axis_rx_tdata[6:2];

        if (m_axis_rx_tlast) begin
          m_ul_arvalid <= 1'b1;
          state        <= STATE_RD32_STALL;
        end
      end
    end

    STATE_RD32_STALL: begin
      if (m_ul_arvalid && m_ul_arready) begin
        m_ul_arvalid <= 1'b0;
        m_ul_rready  <= 1'b1;

        state        <= STATE_RD32_NF;
      end
    end

    STATE_RD32_NF: begin
      if (m_ul_rvalid && m_ul_rready) begin
        m_ul_rready  <= 1'b0;
        readdata_t   <= m_ul_rdata;
        state        <= STATE_RD32_R1;

        s_axis_tx_tdata  <= {cfg_completer_id, 3'b000, 1'b0, { 2'b0, pcie_len_dw, 2'b0 },
                             1'b0, CPL_DATA_FMT_TYPE, 1'b0, pcie_tc, 4'b0, 1'b0, 1'b0, pcie_attr, 2'b0, { 2'b0, pcie_len_dw } };
        s_axis_tx_tkeep  <= 8'hFF;
        s_axis_tx_tvalid <= 1'b1;
      end
    end

    STATE_RD32_R1: begin
      if (s_axis_tx_tready) begin
        s_axis_tx_tdata <= { readdata,
                             pcie_req_id, pcie_tag, 1'b0, pcie_low_addr, 2'b0 };
        state           <= STATE_RD32_R2;
        pcie_len_dw     <= pcie_len_dw - 1'b1;
        if (pcie_len_dw == 8'h1) begin
          s_axis_tx_tlast <= 1'b1;
        end
      end
    end

    STATE_RD32_R2: begin
      if (s_axis_tx_tready) begin
        if (s_axis_tx_tlast) begin
          state            <= STATE_RESET;
        end else begin
          m_ul_araddr     <= m_ul_araddr + 1'b1;
          m_ul_arvalid    <= 1'b1;
          state           <= STATE_RD32_ANS;
        end

        s_axis_tx_tlast  <= 1'b0;
        s_axis_tx_tvalid <= 1'b0;
      end
    end

    STATE_RD32_ANS: begin
      if (m_ul_arvalid && m_ul_arready) begin
        m_ul_arvalid <= 1'b0;
        m_ul_rready  <= 1'b1;
        state        <= STATE_RD32_RN;
      end
    end

    STATE_RD32_RN: begin
      if (m_ul_rvalid && m_ul_rready) begin
        m_ul_rready           <= 1'b0;
        s_axis_tx_tdata[31:0] <= m_ul_rdata;
        s_axis_tx_tkeep       <= 8'h0f;
        pcie_len_dw           <= pcie_len_dw - 1'b1;
        if (pcie_len_dw == 8'h1) begin
          state            <= STATE_RD32_R2;
          s_axis_tx_tlast  <= 1'b1;
          s_axis_tx_tvalid <= 1'b1;
        end else begin
          state            <= STATE_RD32_ANS2;
          m_ul_araddr      <= m_ul_araddr + 1'b1;
          m_ul_arvalid     <= 1'b1;
        end
      end
    end

    STATE_RD32_ANS2: begin
      if (m_ul_arvalid && m_ul_arready) begin
        m_ul_arvalid <= 1'b0;
        m_ul_rready  <= 1'b1;
        state        <= STATE_RD32_RN2;
      end
    end

    STATE_RD32_RN2: begin
      if (m_ul_rvalid && m_ul_rready) begin
        m_ul_rready            <= 1'b0;
        s_axis_tx_tdata[63:32] <= m_ul_rdata;
        s_axis_tx_tkeep        <= 8'hff;
        state                  <= STATE_RD32_R2;
        s_axis_tx_tvalid       <= 1'b1;
        pcie_len_dw            <= pcie_len_dw - 1'b1;
        if (pcie_len_dw == 8'h1) begin
          s_axis_tx_tlast      <= 1'b1;
        end
      end
    end

    STATE_SKIP: begin
      if (m_axis_rx_tlast && m_axis_rx_tvalid) begin
        state <= STATE_RESET;
      end
    end
    endcase

  end
end

endmodule
