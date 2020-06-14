//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module dma_config #(
    parameter DMA_BUFFS_BITS = 5
)(
    // UL
    input           s_ul_clk,

    // UL Write channel
    input [DMA_BUFFS_BITS - 1:0]  s_ul_waddr,
    input [31:0]                  s_ul_wdata,
    input                         s_ul_wvalid,

    // Control IF
    input                         dma_en,
    input [DMA_BUFFS_BITS - 1:0]  dma_bufno,

    // Output config
    output [31:12]                dma_addr_out,
    output [11:0]                 dma_buflen_out
);

//////////////////////////////////////////////////////////
// DMA Write REG
// 20bit physical addr + 12bit length of buffer in 16-bytes values

wire [DMA_BUFFS_BITS - 1:0]  dma_addr = (dma_en) ? dma_bufno : s_ul_waddr;
wire                         dma_we   = (~dma_en && s_ul_wvalid);

ram32xsp #(.WIDTH(32)) dmacfg(
    .wclk(s_ul_clk),
    .we(dma_we),
    .addr(dma_addr),
    .datai(s_ul_wdata),
    .datao({dma_addr_out, dma_buflen_out})
);

endmodule
