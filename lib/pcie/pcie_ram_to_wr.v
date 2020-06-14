//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module pcie_ram_to_wr #(
    parameter BUFFER_SIZE_BITS = 17,
    parameter BUFFER_BUS_ADDRESS = 32,
    parameter MEM_TAG = 1,
    parameter BUFFER_BURST_BITS = 5
)(
    // UL
    input                            s_ul_clk,
    input                            s_ul_aresetn,

    input                            ul_lm_rvalid,
    output reg                       ul_lm_rready,
    input [BUFFER_SIZE_BITS - 1:3]   ul_lm_rlocaddr,
    input [BUFFER_BUS_ADDRESS - 1:3] ul_lm_rbusaddr,
    input [BUFFER_BURST_BITS - 1:0]  ul_lm_rlength,
    input [MEM_TAG-1:0]              ul_lm_rtag,
    // Bus data move confirmation
    output reg                       ul_lm_tvalid,
    input                            ul_lm_tready,
    output reg [MEM_TAG-1:0]         ul_lm_ttag,

    input [1:0]                      cfg_pcie_attr,
    input [15:0]                     cfg_pcie_reqid,

    // AXIs PCIe TX
    input                            m_axis_tx_tready,
    output reg [63:0]                m_axis_tx_tdata,
    output reg [7:0]                 m_axis_tx_tkeep,
    output reg                       m_axis_tx_tlast,
    output reg                       m_axis_tx_tvalid,

    // RAM interface
    input  [63:0]                    bram_data_rd,
    output reg [BUFFER_SIZE_BITS-1:3]bram_addr,
    output                           bram_en
);

wire [63:0] data_to_pcie;
bsswap bs0 (.in(bram_data_rd[31:0]),  .out(data_to_pcie[31:0]));
bsswap bs1 (.in(bram_data_rd[63:32]), .out(data_to_pcie[63:32]));

wire  [BUFFER_BURST_BITS:0] ul_lm_rlength_z = ul_lm_rlength + 1;
wire  [9:0]                 pcie_lm_length = { ul_lm_rlength_z, 1'b0 };

reg   [BUFFER_BURST_BITS:0] pcie_burst_counter;
wire                        pcie_burst_last = pcie_burst_counter[BUFFER_BURST_BITS];

reg                         pcie_pkt_last;

reg [1:0]                   dma_state;

reg [31:0]                  tmp_axis_data_wrap;


localparam DMA_RAM_LOAD       = 0;
localparam DMA_FILL_PCIE_HDR  = 1;
localparam DMA_FILL_PCIE_ADDR = 2;
localparam DMA_PCIE_TRANSFER  = 3;

wire in_rd_pipe_valid = (dma_state != DMA_RAM_LOAD) && ~pcie_burst_last;
wire in_rd_pipe_ready;

wire mem_oready = (dma_state == DMA_FILL_PCIE_ADDR || dma_state == DMA_PCIE_TRANSFER) && m_axis_tx_tready;

reg mem_ovalid;
assign in_rd_pipe_ready = ~mem_ovalid || mem_oready;

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    mem_ovalid <= 1'b0;
  end else begin
    if ((mem_ovalid && mem_oready) || (~mem_ovalid && in_rd_pipe_valid)) begin
      mem_ovalid <= in_rd_pipe_valid;
    end
  end
end

assign bram_en = (in_rd_pipe_ready && in_rd_pipe_valid);

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    dma_state            <= DMA_RAM_LOAD;
    m_axis_tx_tvalid     <= 1'b0;

    ul_lm_rready         <= 1'b0;
    ul_lm_tvalid         <= 1'b0;
  end else begin

    if (m_axis_tx_tready && m_axis_tx_tvalid) begin
      m_axis_tx_tvalid     <= 1'b0;
    end

    if (bram_en) begin
      bram_addr          <= bram_addr          + 1'b1;
      pcie_burst_counter <= pcie_burst_counter - 1'b1;
    end

    if (ul_lm_rready && ul_lm_rvalid) begin
      ul_lm_rready <= 1'b0;
    end

    if (ul_lm_tvalid && ul_lm_tready) begin
      ul_lm_tvalid <= 1'b0;
    end

    case (dma_state)
     DMA_RAM_LOAD: begin
      if (ul_lm_rvalid && (ul_lm_tready || ~ul_lm_tvalid)) begin
        bram_addr          <= ul_lm_rlocaddr;
        pcie_burst_counter <= { 1'b0, ul_lm_rlength };
        dma_state          <= DMA_FILL_PCIE_HDR;
      end
     end

     DMA_FILL_PCIE_HDR: begin
      if ((m_axis_tx_tready || ~m_axis_tx_tvalid)) begin
        m_axis_tx_tvalid <= 1'b1;
        m_axis_tx_tkeep  <= 8'hff;
        m_axis_tx_tdata  <= {
            cfg_pcie_reqid,
            8'b0000_0000, 8'b1111_1111,
            1'b0, 7'b10_00000, 1'b0, 3'b000, 4'b0000,
            1'b0, 1'b0, cfg_pcie_attr, 2'b00, pcie_lm_length };

        m_axis_tx_tlast  <= 1'b0;
        pcie_pkt_last    <= 1'b0;
        dma_state        <= DMA_FILL_PCIE_ADDR;
      end
     end

     DMA_FILL_PCIE_ADDR: begin
      if (m_axis_tx_tready) begin
        m_axis_tx_tvalid   <= 1'b1;
        m_axis_tx_tkeep    <= (pcie_pkt_last) ? 8'h0f : 8'hff;
        m_axis_tx_tdata    <= { data_to_pcie[31:0], ul_lm_rbusaddr, 3'b000 };
        m_axis_tx_tlast    <= pcie_pkt_last;

        tmp_axis_data_wrap <= data_to_pcie[63:32];

        pcie_pkt_last      <= pcie_burst_last;
        if (pcie_burst_last && ~pcie_pkt_last) begin
          ul_lm_tvalid     <= 1'b1;
        end

        dma_state          <= DMA_PCIE_TRANSFER;

        ul_lm_rready       <= 1'b1;
        ul_lm_ttag         <= ul_lm_rtag;
      end
     end

     DMA_PCIE_TRANSFER: begin
      if (m_axis_tx_tready) begin
        m_axis_tx_tvalid   <= 1'b1;
        m_axis_tx_tkeep    <= (pcie_pkt_last) ? 8'h0f : 8'hff;
        m_axis_tx_tdata    <= { data_to_pcie[31:0], tmp_axis_data_wrap };
        m_axis_tx_tlast    <= pcie_pkt_last;

        tmp_axis_data_wrap <= data_to_pcie[63:32];

        pcie_pkt_last      <= pcie_burst_last;
        if (pcie_burst_last && ~pcie_pkt_last) begin
          ul_lm_tvalid     <= 1'b1;
        end

        if (pcie_pkt_last) begin
          if (ul_lm_rvalid && (ul_lm_tready || ~ul_lm_tvalid)) begin
            bram_addr          <= ul_lm_rlocaddr;
            pcie_burst_counter <= { 1'b0, ul_lm_rlength };
            dma_state          <= DMA_FILL_PCIE_HDR;
          end else begin
            dma_state          <= DMA_RAM_LOAD;
          end
        end
      end
     end
    endcase

  end
end


endmodule
