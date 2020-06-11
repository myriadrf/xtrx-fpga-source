//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// UL SPI 32bit
//
// Write registers
// read data isn't bufferred !
//

module axis_spi #(
    parameter DATA_WIDTH = 32,
    parameter WR_ONLY = 0,
    parameter POL_LO = 0,
    parameter SCK_LO = 1,
    parameter FIXED_DIV = 2,
    parameter HOLD_SEN = 0,
    parameter DIV_BITS =
//        ( FIXED_DIV < 2 )   ? 1 : 
        ( FIXED_DIV < 4 )   ? 2 : 
        ( FIXED_DIV < 8 )   ? 3 :
        ( FIXED_DIV < 16 )  ? 4 :
        ( FIXED_DIV < 32 )  ? 5 :
        ( FIXED_DIV < 64 )  ? 6 :
        ( FIXED_DIV < 128 ) ? 7 : 8
)(
    // UL clocks
    input                     axis_clk,
    input                     axis_resetn,

    // UL Write channel
    input [DATA_WIDTH - 1:0]  axis_wdata,
    input                     axis_wvalid,
    output reg                axis_wready,

    // Output data readback stream
    output [DATA_WIDTH - 1:0] axis_rdata,
    output                    axis_rvalid,
    input                     axis_rready,

    // SPI master
    output                    spi_mosi,
    input                     spi_miso,
    output reg                spi_sclk,
    output reg                spi_sen,

    output                    spi_interrupt_valid,
    input                     spi_interrupt_ready
);

wire polarity_low = POL_LO;

localparam WAIT_TRANS  = 0;
localparam SPI_TRANS   = 1;
reg       state;

reg [DIV_BITS-1:0] clk_div;
reg [5:0]          iteration;

localparam SPI_CLK_HI   = 0;
localparam SPI_CLK_LO   = 1;
localparam SPI_DEASSERT = 2;
localparam SPI_HOLDSEN  = 3;
reg [1:0] spi_state;

reg [DATA_WIDTH - 1:0]  data_wr;

assign spi_mosi = data_wr[DATA_WIDTH - 1];

// settings
wire [DIV_BITS-1:0] set_clk_div;
reg        finished;

assign spi_interrupt_valid = finished;

localparam SPI_INITIAL_SCLK_VALUE  = (SCK_LO) ? 1'b0 : 1'b1;
localparam SPI_INITIAL_SCLK_IVALUE = (SCK_LO) ? 1'b1 : 1'b0;

wire clk_stobe = (clk_div == 0);

assign  axis_rvalid = 1'b1;

generate
if (WR_ONLY == 0) begin
  reg [DATA_WIDTH - 1:0]  data_rd;

  always @(posedge axis_clk) begin
    if (state == SPI_TRANS && clk_stobe && spi_state == SPI_CLK_HI) begin
      // TODO: read data POL_LO == 1
      data_rd <= {data_rd[DATA_WIDTH - 2:0], spi_miso};
    end
  end

  assign axis_rdata = data_rd;
end else begin
  assign axis_rdata = 0;
end
endgenerate

wire axi_wd_transfer = axis_wvalid && axis_wready;
wire axi_wd_transfer_transaction;

`ifdef USE_DYNAMIC_DIV
generate
if (FIXED_DIV == 0) begin
  reg [DIV_BITS-1:0] set_clk_div_reg;
  assign set_clk_div = set_clk_div_reg;
  assign axi_wd_transfer_transaction = axi_wd_transfer && ~s_ul_waddr;

  // process for setting divider
  always @(posedge axis_clk) begin
    if (!axis_resetn) begin
      set_clk_div_reg     <= 8'hFF;
    end else begin 
      if (axi_wd_transfer) begin
        if (s_ul_waddr) begin
          set_clk_div_reg <= axis_wdata[DIV_BITS-1:0];
        end
      end
    end
  end
end else begin
  assign axi_wd_transfer_transaction = axi_wd_transfer;
  assign set_clk_div = FIXED_DIV;
end
endgenerate
`else
assign axi_wd_transfer_transaction = axi_wd_transfer;
assign set_clk_div = FIXED_DIV;
`endif


always @(posedge axis_clk) begin
  if (!axis_resetn) begin
    state          <= WAIT_TRANS;
    axis_wready    <= 1'b0;

    //SPI
    spi_sen        <= 1'b1;
    spi_sclk       <= SPI_INITIAL_SCLK_VALUE;

    finished       <= 1'b0;
  end else begin
    case (state)
      WAIT_TRANS : begin
        if (axi_wd_transfer_transaction) begin
          data_wr      <= axis_wdata;
          axis_wready  <= 1'b0;
          finished     <= 1'b0;

          state        <= SPI_TRANS;
          if (HOLD_SEN) begin
            spi_state    <= SPI_HOLDSEN;
          end else begin
            spi_state    <= SPI_CLK_LO;
            spi_sen      <= 1'b0;
          end
          clk_div      <= set_clk_div;
          iteration    <= DATA_WIDTH - 1;
        end else begin
          if (spi_interrupt_valid && spi_interrupt_ready) begin
            finished <= 1'b0;
          end
          axis_wready  <= 1'b1;
        end
      end

      SPI_TRANS : begin
        if (clk_stobe) begin
          clk_div      <= set_clk_div;

          case (spi_state)
            SPI_HOLDSEN: begin
              if (HOLD_SEN) begin
                spi_sclk     <= ~spi_sclk;
                if (spi_sclk == SPI_INITIAL_SCLK_IVALUE) begin
                  spi_sen      <= 1'b0;
                  if (POL_LO)
                    spi_state    <= SPI_CLK_HI;
                  else
                    spi_state    <= SPI_CLK_LO;
                end
              end
            end
            SPI_CLK_LO : begin
              spi_sclk     <= 1'b1;
              if (polarity_low && (iteration != (DATA_WIDTH - 1))) begin
                data_wr      <= {data_wr[DATA_WIDTH - 2:0],     1'b0};
              end

              spi_state    <= SPI_CLK_HI;
            end
            SPI_CLK_HI : begin
              spi_sclk     <= 1'b0;
              // MSB first
              if (~polarity_low) begin
                data_wr      <= {data_wr[DATA_WIDTH - 2:0],     1'b0};
              end
              
              if (iteration == 0) begin
                spi_state    <= SPI_DEASSERT;
              end else begin
                iteration    <= iteration - 1;
                spi_state    <= SPI_CLK_LO;
              end
            end
            SPI_DEASSERT : begin
              spi_sen      <= 1'b1;
              state        <= WAIT_TRANS;
              axis_wready  <= 1'b1;
              //end
              finished     <= 1'b1;
              spi_sclk     <= SPI_INITIAL_SCLK_VALUE;
            end
          endcase

        end else begin
          clk_div <= clk_div - 1;
        end
      end
    endcase
  end
end

endmodule
