//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

// i2c dual bus master multiple device controller

// TX[31]    - RD_VALID 0 - only WR, 1 - RD cycle after WR
// TX[30:28] - RDZ_SZ (0 - 1 byte -- skip read cycle, .. 7 - 8 bytes (but only 4 last will be stored in reg))
// TX[27:26] - WR_SZ (0 - 0 byte -- skip write cycle, 1 - 1 bytes, .. 3 - 3 bytes)

// TX[25:24] - Device Address Select from LUT (WR byte 0 -- address)

// TX[23:16] - WR byte 3
// TX[15:8]  - WR byte 2
// TX[7:0]   - WR byte 1
//
//
// dev_lut[7:1],   dev_lut[0]  - DEV0 Address, busno
// dev_lut[15:9],  dev_lut[8]  - DEV1 Address, busno
// dev_lut[23:16], dev_lut[16] - DEV2 Address, busno
// dev_lut[31:25], dev_lut[24] - DEV3 Address, busno
//
module ul_i2c_dme #(
    parameter I2C_SPEED = 100000,
    parameter BUS_SPEED = 125000000,
    parameter REPORT_ERROR = 1
)(
    // UL clocks
    input   clk,
    input   reset,

    input [31:0] dev_lut,

    // BUS 1
    input  sda1_in,
    output sda1_out_eo,
    output scl1_out_eo,

    // BUS 2
    input  sda2_in,
    output sda2_out_eo,
    output scl2_out_eo,

    input         axis_cmdreg_valid,
    input [31:0]  axis_cmdreg_data,
    output        axis_cmdreg_ready,

    output        axis_rbdata_valid,
    output [31:0] axis_rbdata_data,
    input         axis_rbdata_ready,

    input         int_ready,
    output reg    int_valid
);


localparam I2CDM_WR_RDVAL_OFF = 31;
localparam I2CDM_WR_RDSZ_OFF  = 28;
localparam I2CDM_WR_WRSZ_OFF  = 26;
localparam I2CDM_WR_DEVNO_OFF = 24;

localparam ST_NONE  = 0;
localparam ST_WDATA = 1;
localparam ST_STRD  = 2;
localparam ST_RDATA = 3;

reg [1:0]  state;

reg        i2c_rdvalid;
reg [2:0]  i2c_rdcnt;
reg [1:0]  i2c_wrcnt;
reg [1:0]  i2c_devsel;

reg [23:0] wr_data;

reg [31:0] rd_data;


assign axis_cmdreg_ready = (state == ST_NONE);

assign axis_rbdata_valid    = 1'b1;
assign axis_rbdata_data     = rd_data;

reg [7:0] axis_iic_tx_data;
reg       axis_iic_tx_valid;
reg       axis_iic_tx_last;
wire      axis_iic_tx_ready;
wire [3:0] axis_iic_tx_user;

wire [7:0] axis_iic_rx_data;
wire       axis_iic_rx_valid;
wire       axis_iic_rx_last;
wire       axis_iic_rx_ready = 1'b1;

wire       cmd_error;

ll_i2c_dmastere  #(
    .I2C_SPEED(I2C_SPEED),
    .BUS_SPEED(BUS_SPEED)
) ll_i2c_dmastere (
    .reset(reset),
    .axis_clk(clk),

    .sda1_in(sda1_in),
    .sda1_out_eo(sda1_out_eo),
    .scl1_out_eo(scl1_out_eo),

    .sda2_in(sda2_in),
    .sda2_out_eo(sda2_out_eo),
    .scl2_out_eo(scl2_out_eo),

    .axis_tx_data(axis_iic_tx_data),
    .axis_tx_last(axis_iic_tx_last),
    .axis_tx_valid(axis_iic_tx_valid),
    .axis_tx_user(axis_iic_tx_user),
    .axis_tx_ready(axis_iic_tx_ready),

    .axis_rx_data(axis_iic_rx_data),
    .axis_rx_last(axis_iic_rx_last),
    .axis_rx_valid(axis_iic_rx_valid),
    .axis_rx_ready(axis_iic_rx_ready),

    .cmd_error(cmd_error)
);


always @(posedge clk) begin
  if (reset) begin
    int_valid <= 1'b0;
  end else begin
    if (axis_iic_rx_last && axis_iic_rx_valid) begin
      int_valid <= 1'b1;
    end else if (int_valid && int_ready) begin
      int_valid <= 1'b0;
    end
  end
end

wire       cmd_rdval= axis_cmdreg_data[I2CDM_WR_RDVAL_OFF];
wire [2:0] cmd_rdzsz = axis_cmdreg_data[I2CDM_WR_RDSZ_OFF + 2:I2CDM_WR_RDSZ_OFF];
wire [1:0] cmd_wrsz = axis_cmdreg_data[I2CDM_WR_WRSZ_OFF + 1:I2CDM_WR_WRSZ_OFF];
wire [1:0] cmd_devsel = axis_cmdreg_data[I2CDM_WR_DEVNO_OFF + 1:I2CDM_WR_DEVNO_OFF];

wire [7:0] i2c_addr_bus = (cmd_devsel == 2'b00) ? dev_lut[7:0] :
                          (cmd_devsel == 2'b01) ? dev_lut[15:8] :
                          (cmd_devsel == 2'b10) ? dev_lut[23:16] : dev_lut[31:24];
wire [7:0] rd_i2c_addr = (i2c_devsel == 2'b00) ? dev_lut[7:0] :
                         (i2c_devsel == 2'b01) ? dev_lut[15:8] :
                         (i2c_devsel == 2'b10) ? dev_lut[23:16] : dev_lut[31:24];


assign axis_iic_tx_user  = { i2c_rdcnt, rd_i2c_addr[7] };

always @(posedge clk) begin
  if (reset) begin
    state             <= ST_NONE;
    axis_iic_tx_valid <= 1'b0;
  end else begin
    case (state)
    ST_NONE: begin
      if (axis_cmdreg_valid && axis_cmdreg_ready) begin
        state             <= ST_WDATA;

        axis_iic_tx_data  <= { i2c_addr_bus[6:0], 1'b0 };
        axis_iic_tx_valid <= 1'b1;
        axis_iic_tx_last  <= 1'b0;

        wr_data           <= axis_cmdreg_data[23:0];

        i2c_rdvalid       <= cmd_rdval;
        i2c_rdcnt         <= cmd_rdzsz;
        i2c_wrcnt         <= cmd_wrsz;
        i2c_devsel        <= cmd_devsel;
      end
    end

    ST_WDATA: begin
      if (/*axis_iic_tx_valid && */ axis_iic_tx_ready) begin
        if (i2c_wrcnt == 0) begin
            state             <= ST_STRD;
        end

        i2c_wrcnt         <= i2c_wrcnt - 1;

        axis_iic_tx_data  <= wr_data[7:0];
        axis_iic_tx_last  <= (i2c_wrcnt == 0);

        wr_data[15:0]     <= wr_data[23:8];
      end
    end

    ST_STRD: begin
      if (/*axis_iic_tx_valid && */ axis_iic_tx_ready) begin
        if (i2c_rdvalid) begin
          axis_iic_tx_data   <= { rd_i2c_addr[6:0], 1'b1 };
          state              <= ST_RDATA;
        end else begin
          axis_iic_tx_valid  <= 0;
          state              <= ST_NONE;
        end

        axis_iic_tx_last    <= 1;
      end
    end

    ST_RDATA: begin
      if (/*axis_iic_tx_valid && */ axis_iic_tx_ready) begin
        axis_iic_tx_valid  <= 0;
      end

      if (axis_iic_rx_valid  /* && axis_iic_rx_ready*/) begin

        rd_data[31:8] <= (cmd_error && REPORT_ERROR) ? 24'hffffff : rd_data[24:0];
        rd_data[7:0]  <= (cmd_error && REPORT_ERROR) ?  8'hff     : axis_iic_rx_data;

        if (axis_iic_rx_last) begin
          state             <= ST_NONE;
        end
      end
    end

    endcase
  end
end


endmodule
