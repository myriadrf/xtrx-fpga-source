//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module pcie_req_to_ram #(
    parameter LOW_ADDDR_BITS = 14
)(
    // UL
    input             s_ul_clk,
    input             s_ul_aresetn,

    input             txdma_active,

    input   [15:0]    cfg_pcie_reqid,

    // AXIs PCIe TX (completion)
    output            s_axis_rx_tready,
    input   [63:0]    s_axis_rx_tdata,
    input   [7:0]     s_axis_rx_tkeep,
    input             s_axis_rx_tlast,
    input             s_axis_rx_tvalid,

    input             m_axis_tx_tready,
    output reg [63:0] m_axis_tx_tdata,
    output reg [7:0]  m_axis_tx_tkeep,
    output reg        m_axis_tx_tlast,
    output reg        m_axis_tx_tvalid,

    // RAM interface
    output [63:0]                m_ram_tdata,
    output [LOW_ADDDR_BITS-1:0]  m_ram_taddr,
    output                       m_ram_tvalid,

    // Request & notify
    input                        ul_ml_rvalid,
    output                       ul_ml_rready,
    input [LOW_ADDDR_BITS+3-1:3] ul_ml_rlocaddr,
    input [31:3]                 ul_ml_rbusaddr,
    input [8:0]                  ul_ml_rlength,
    input [4:0]                  ul_ml_rtag,

    output                       ul_ml_tvalid,
    input                        ul_ml_tready,
    output [4:0]                 ul_ml_ttag
);

localparam REQ_TAG_BITS = 5;

wire [LOW_ADDDR_BITS-1:0] buffer_burst_cpld_addr;

wire        pcie_rtag_rd_latch;
wire [4:0]  pcie_rtag_rd;         // cpld TAG

ram32xsdp #(.WIDTH(LOW_ADDDR_BITS)) tag_waddr(
    .wclk(s_ul_clk),
    .we(ul_ml_rvalid),
    .waddr(ul_ml_rtag),
    .datai(ul_ml_rlocaddr),
    .raddr(pcie_rtag_rd),
    .datao(buffer_burst_cpld_addr)
);

localparam ST_W0 = 0;
localparam ST_W1 = 1;
reg state;

assign ul_ml_rready = m_axis_tx_tready && state;

wire [31:2] pcie_addr   = { ul_ml_rbusaddr, 1'b0 };
wire [7:0]  pcie_tag    =   ul_ml_rtag;
wire [9:0]  pcie_length = { ul_ml_rlength + 1'b1, 1'b0 };

wire [1:0]  cfg_pcie_attr = 0;

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    state            <= 1'b0;
    m_axis_tx_tvalid <= 1'b0;
  end else begin

    case (state)
      ST_W0: begin
        if (ul_ml_rvalid && (!m_axis_tx_tvalid || m_axis_tx_tvalid && m_axis_tx_tready) ) begin
          m_axis_tx_tdata[63:32] <= { cfg_pcie_reqid, pcie_tag, 8'hff};
          m_axis_tx_tdata[31:0]  <= { 16'h00_00,      2'b00, cfg_pcie_attr, pcie_length };
          m_axis_tx_tkeep        <= 8'hff;
          m_axis_tx_tlast        <= 1'b0;
          m_axis_tx_tvalid       <= 1'b1;
          state                  <= state + 1;
        end else if (m_axis_tx_tvalid && m_axis_tx_tready) begin
          m_axis_tx_tvalid <= 1'b0;
        end
      end

      ST_W1: begin
        if (m_axis_tx_tready) begin
          m_axis_tx_tdata[31:0] <= {pcie_addr, 2'b0};
          m_axis_tx_tkeep       <= 8'h0f;
          m_axis_tx_tlast       <= 1'b1;
          m_axis_tx_tvalid      <= 1'b1;
          state                 <= state + 1;
        end
      end

    endcase

  end
end


assign ul_ml_tvalid = pcie_rtag_rd_latch;
assign ul_ml_ttag   = pcie_rtag_rd;


localparam CPL_FMT_TYPE =           7'b00_01010;   // 3DW
localparam CPL_DATA_FMT_TYPE =      7'b10_01010;   // 3DW + data
localparam MEM_WR32_FMT_TYPE =      7'b10_00000;   // 3DW + data

localparam ST_RX_TLP_HDR    = 0;
localparam ST_RX_TLP_W0     = 1;
localparam ST_RX_TLP_WBULK  = 2;
localparam ST_RX_TLP_SKIP   = 3;


reg [1:0]  dma_rx_state;

reg [31:0] tmp_axis_rx_data_wrap;

wire [6:0] tlp_type   = s_axis_rx_tdata[30:24];
wire       tlp_ep     = s_axis_rx_tdata[14];
wire       tlp_dp     = s_axis_rx_tdata[15];
wire [3:0] tlp_ldwbe  = s_axis_rx_tdata[39:36];
wire [3:0] tlp_fdwbe  = s_axis_rx_tdata[35:32];
wire [2:0] cpld_status_bits = s_axis_rx_tdata[47:45];

reg        first_word;

assign s_axis_rx_tready = 1'b1;


reg       pcie_last_cpld_packet;

assign pcie_rtag_rd       = s_axis_rx_tdata[REQ_TAG_BITS - 1 + 8:8];
wire   pcie_rtag_rd_pres  = (dma_rx_state == ST_RX_TLP_W0) && s_axis_rx_tvalid && s_axis_rx_tready;
assign pcie_rtag_rd_latch = pcie_rtag_rd_pres && pcie_last_cpld_packet;

//reg       buffer_burst_cpld_lastreq_reg;
reg [10:1] data_remain;
reg       last_burst_in_buffer;

wire [63:0] pcie_to_fifo;
bsswap bs0(.in(s_axis_rx_tdata[31:0]),  .out(pcie_to_fifo[31:0]));
bsswap bs1(.in(s_axis_rx_tdata[63:32]), .out(pcie_to_fifo[63:32]));


reg [7:0] invalid_cpld;
reg [7:0] cpl_stat_ur;
reg [7:0] cpl_stat_csr;
reg [7:0] cpl_stat_ca;

localparam CPL_UR  = 3'b001;
localparam CPL_CSR = 3'b010;
localparam CPL_CA  = 3'b100;

reg [LOW_ADDDR_BITS-1:0]    fifo_wr_addr;
reg [63:0]                  fifo_data_in;
reg                         fifo_wr_en_rx;

reg pcie_cpl_trans;

always @(posedge s_ul_clk) begin
  if (txdma_active) begin
    fifo_wr_addr         <= 0;

    fifo_wr_en_rx        <= 1'b0;

    dma_rx_state         <= ST_RX_TLP_HDR;

    invalid_cpld <= 0;
    cpl_stat_ur  <= 0;
    cpl_stat_csr <= 0;
    cpl_stat_ca  <= 0;
  end else begin
    case (dma_rx_state)
      ST_RX_TLP_HDR: begin
        //pcie_rx_valid            <= 1'b0;
        fifo_wr_en_rx            <= 1'b0;

        if (s_axis_rx_tready && s_axis_rx_tvalid) begin
          // Last CplD packet is when Length == ByteCount >> 2, garbage on MemWr
          pcie_last_cpld_packet <= (s_axis_rx_tdata[9:0] == s_axis_rx_tdata[32+2+9:32+2]);
          data_remain[9:1]      <=  s_axis_rx_tdata[32+2+9:32+2+1];
          data_remain[10]       <=  (s_axis_rx_tdata[32+2+9:32+2+1] == 9'b0) ? 1'b1 : 1'b0;
          //pcie_rx_length_qw[9:1]<= s_axis_rx_tdata[9:1];

          if (tlp_ep == 1'b0 &&
               (/*fifo_dma_en &&*/ tlp_type == CPL_DATA_FMT_TYPE || /*~fifo_dma_en &&*/ tlp_fdwbe == 4'hF && tlp_type == MEM_WR32_FMT_TYPE)) begin
            pcie_cpl_trans <= (tlp_type == CPL_DATA_FMT_TYPE);
            dma_rx_state <= ST_RX_TLP_W0;
          end else begin
            // Log type of abortion
            if (tlp_type == CPL_FMT_TYPE) begin
              if (cpld_status_bits & CPL_UR) begin
                cpl_stat_ur <= cpl_stat_ur + 1'b1;
              end
              if (cpld_status_bits & CPL_CSR) begin
                cpl_stat_csr <= cpl_stat_csr + 1'b1;
              end
              if (cpld_status_bits & CPL_CA) begin
                cpl_stat_ca <= cpl_stat_ca + 1'b1;
              end
            end

            invalid_cpld <= invalid_cpld + 1'b1;
            dma_rx_state <= ST_RX_TLP_SKIP;
          end

        end
      end

      ST_RX_TLP_W0: begin
        if (s_axis_rx_tready && s_axis_rx_tvalid) begin
          tmp_axis_rx_data_wrap    <= pcie_to_fifo[63:32];
          dma_rx_state             <= ST_RX_TLP_WBULK;

          // For PCIe write
          // load fifo_wr_addr
          if (/*~fifo_dma_en*/ ~pcie_cpl_trans) begin
            fifo_wr_addr                <= s_axis_rx_tdata[LOW_ADDDR_BITS+2:3];
          end else begin
            fifo_wr_addr                <= buffer_burst_cpld_addr - data_remain;
          end

          first_word                    <= 1'b0;
        end
      end

      ST_RX_TLP_WBULK: begin
        if (s_axis_rx_tready && s_axis_rx_tvalid) begin
          fifo_data_in[31:0]       <= tmp_axis_rx_data_wrap;
          fifo_data_in[63:32]      <= pcie_to_fifo[31:0];
          tmp_axis_rx_data_wrap    <= pcie_to_fifo[63:32];

          fifo_wr_en_rx            <= 1'b1;
          fifo_wr_addr             <= fifo_wr_addr + first_word;
          first_word               <= 1'b1;
          if (s_axis_rx_tlast) begin
            dma_rx_state           <= ST_RX_TLP_HDR;
          end
        end else begin
          fifo_wr_en_rx            <= 1'b0;
        end
      end

      ST_RX_TLP_SKIP: begin
        // Write metada for next burst
        if (s_axis_rx_tready && s_axis_rx_tvalid && s_axis_rx_tlast) begin
          dma_rx_state           <= ST_RX_TLP_HDR;
        end
      end
    endcase

  end
end


assign m_ram_tdata = fifo_data_in;
assign m_ram_taddr = fifo_wr_addr;
assign m_ram_tvalid = fifo_wr_en_rx;

endmodule
