//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module ll_i2c_dmastere #(
    parameter I2C_SPEED = 100000,
    parameter BUS_SPEED = 62500000,
    parameter CLK_DIV_BITS = 12,
    parameter RD_BITS_MAX = 3
)(
    input reset,
    input axis_clk,

    // BUS 1
    input  sda1_in,
    output sda1_out_eo,
    output scl1_out_eo,

    // BUS 2
    input  sda2_in,
    output sda2_out_eo,
    output scl2_out_eo,

    input [7:0]  axis_tx_data,
    input        axis_tx_last,
    input        axis_tx_valid,
    input [RD_BITS_MAX:0]  axis_tx_user,
      // [3:1]   Number of bytes to read 0==1, 1==2, etc.
      // [0]     Bus number
    output       axis_tx_ready,

    output [7:0] axis_rx_data,
    output       axis_rx_last,
    output       axis_rx_valid,
    input        axis_rx_ready,
    
    output reg   cmd_error
);

reg i2c_bus_sel;
reg dss_bus_sel;

// Bus logic selector
wire sda_in = (dss_bus_sel) ? sda2_in : sda1_in;
wire sda_out_eo;
wire scl_out_eo;

localparam SDA_OUT_HIGH = 0;
localparam SDA_OUT_LOW  = 1;

localparam SCL_OUT_HIGH = 0;
localparam SCL_OUT_LOW  = 1;

assign sda1_out_eo = (dss_bus_sel) ? SDA_OUT_HIGH : sda_out_eo;
assign scl1_out_eo = (dss_bus_sel) ? SCL_OUT_HIGH : scl_out_eo;
assign sda2_out_eo = (dss_bus_sel) ? sda_out_eo : SDA_OUT_HIGH;
assign scl2_out_eo = (dss_bus_sel) ? scl_out_eo : SCL_OUT_HIGH;

// Clock divider block
reg [CLK_DIV_BITS-1:0] clk_div;
reg [1:0]              clk_state;
reg                    clk_state_lo_prev;

always @(posedge axis_clk) begin
  if (reset) begin
    clk_div   <= 0;
    clk_state <= 0;
    clk_state_lo_prev <= 0;
  end else begin
    if (clk_div == ((BUS_SPEED/I2C_SPEED - 1)/4)) begin
      clk_state <= clk_state + 1;
      clk_div   <= 0;
    end else begin
      clk_div <= clk_div + 1;
    end

    clk_state_lo_prev <= clk_state[0];
  end
end

wire state_strobe = (clk_state_lo_prev != clk_state[0]);

// Symbol serialyzer block
localparam LLS_IDLE     = 0;
localparam LLS_START    = 1;
localparam LLS_STOP     = 2;
localparam LLS_TX_BIT_0 = 3;
localparam LLS_TX_BIT_1 = 4;
localparam LLS_RX_BIT   = 5;
localparam LLS_REPSTART = 6;

reg        scl_out_eo_reg;
reg        sda_out_eo_reg;


reg [2:0]  ll_sym;
wire       nxt_sym = (state_strobe && clk_state == 3);
reg        ll_rx_cap;     // Captured RX-bit

assign sda_out_eo = sda_out_eo_reg;
assign scl_out_eo = scl_out_eo_reg;

always @(posedge axis_clk) begin
  if (reset) begin
    scl_out_eo_reg <= SCL_OUT_HIGH;
    sda_out_eo_reg <= SDA_OUT_HIGH;
    dss_bus_sel    <= 0;
    //ll_ready       <= 1'b0;
  end else if (state_strobe) begin
    case (clk_state)
    0: begin
      //dss_bus_sel <= i2c_bus_sel;
      if (ll_sym == LLS_REPSTART || ll_sym == LLS_TX_BIT_1 || ll_sym == LLS_RX_BIT) begin
        sda_out_eo_reg <= SCL_OUT_HIGH;
      end else if (ll_sym == LLS_STOP || ll_sym == LLS_TX_BIT_0) begin
        sda_out_eo_reg <= SCL_OUT_LOW;
      end
    end

    1: begin
      if (ll_sym != LLS_IDLE) begin
        scl_out_eo_reg <= SCL_OUT_HIGH;
      end
    end

    2: begin
      if (ll_sym == LLS_START || ll_sym == LLS_REPSTART) begin
        sda_out_eo_reg <= SDA_OUT_LOW;
      end else if (ll_sym == LLS_STOP) begin
        sda_out_eo_reg <= SDA_OUT_HIGH;
      end else if (ll_sym == LLS_RX_BIT) begin
        ll_rx_cap      <= sda_in;
      end
    end

    3: begin
      dss_bus_sel    <= i2c_bus_sel;
      if (ll_sym != LLS_STOP && ll_sym != LLS_IDLE) begin
        scl_out_eo_reg <= SCL_OUT_LOW;
      end
    end

    endcase
  end
end


// Data stream serialyzer
localparam DSS_IDLE     = 0;
localparam DSS_START    = 1;
localparam DSS_ADDR     = 2;
localparam DSS_AACK     = 3; // ACK by Device
localparam DSS_WDATA    = 4; // Wait for next data frame while waiting for ACK
localparam DSS_TACK     = 5; // ACK by Device Analyze and send 7th but
localparam DSS_TXD      = 6;
localparam DSS_RXD_RACK = 7;
localparam DSS_RDATA    = 8; // Wait for data to be read
localparam DSS_RREP     = 9; // ACK by Master
localparam DSS_STOP     = 10;

localparam DSS_FAILED   = 11; //Transaction aborted by device


reg [2:0] bit_counter;

reg [3:0] dss_state;
reg       dss_mode_r;
reg       dss_last_tx;
reg [RD_BITS_MAX-1:0] dss_rx_cntr;

reg [7:0] rx_data;
reg [7:0] out_data;
assign axis_tx_ready = ~nxt_sym && ((dss_state == DSS_IDLE) || (dss_state == DSS_WDATA) || (dss_state == DSS_FAILED));
assign axis_rx_data  = rx_data;
assign axis_rx_valid = ~nxt_sym && (dss_state == DSS_RDATA);
assign axis_rx_last  = (dss_rx_cntr == 0);

always @(posedge axis_clk) begin
  if (reset) begin
    dss_state   <= DSS_IDLE;
    i2c_bus_sel <= 0; // Make debug easier
    cmd_error   <= 0;
  end else begin
   if (nxt_sym) begin
    case (dss_state)
      DSS_IDLE: begin
        ll_sym      <= LLS_IDLE;
      end

      DSS_START: begin
        ll_sym      <= LLS_START;
        dss_state   <= DSS_ADDR;
        bit_counter <= 0;
        cmd_error   <= 0;
      end

      DSS_ADDR, DSS_TXD: begin
        ll_sym        <= (out_data[7]) ? LLS_TX_BIT_1 : LLS_TX_BIT_0;

        out_data[7:1] <= out_data[6:0];
        bit_counter   <= bit_counter + 1'b1;

        if (bit_counter == 7) begin
          if (dss_state == DSS_ADDR) begin
              dss_mode_r <= out_data[7];
          end
          dss_state   <= DSS_AACK;
        end
      end

      DSS_AACK: begin
        ll_sym          <= LLS_RX_BIT;
        if (dss_mode_r) begin
          dss_state      <= DSS_TACK;
        end else begin
          dss_state      <= DSS_WDATA;
        end
      end

      DSS_WDATA, DSS_TACK: begin
        if (dss_last_tx && ~dss_mode_r) begin
          dss_state     <= DSS_IDLE;
          ll_sym        <= LLS_STOP;
        end else if (ll_rx_cap) begin  // NACK by device
          dss_state     <= DSS_FAILED;
          ll_sym        <= LLS_STOP;
        end else if (dss_mode_r) begin
          dss_state     <= DSS_RXD_RACK;
          ll_sym        <= LLS_RX_BIT;
        end else if (dss_state == DSS_TACK) begin
          ll_sym        <= LLS_IDLE;
          dss_state     <= DSS_TXD;
        end else begin
          ll_sym        <= LLS_IDLE;
        end
      end

      DSS_RXD_RACK: begin
        ll_sym       <= LLS_RX_BIT;
        rx_data[7:0] <= {rx_data[6:0], ll_rx_cap};
        bit_counter  <= bit_counter + 1'b1;

        if (bit_counter == 7) begin
          if (dss_rx_cntr == 0) begin
            ll_sym       <= LLS_TX_BIT_1; //NACK by master, stop transaction
          end else begin
            ll_sym       <= LLS_TX_BIT_0; //ACK by master
          end
          dss_state     <= DSS_RDATA;
        end
      end

      DSS_RDATA: begin
        ll_sym      <= LLS_IDLE;
      end

      DSS_RREP: begin
        ll_sym      <= LLS_RX_BIT;
        dss_state   <= DSS_RXD_RACK;
      end

      DSS_STOP: begin
        ll_sym     <= LLS_STOP;
        dss_state  <= DSS_IDLE;
      end

      default: begin
        ll_sym      <= DSS_IDLE;
        cmd_error   <= 1'b1;
        if (dss_last_tx) begin
          if (dss_mode_r) begin
            //Raise data ready
            dss_rx_cntr <= 0;
            dss_state   <= DSS_RDATA;
          end else begin
            dss_state   <= DSS_IDLE;
          end
        end
      end

    endcase
   end else begin
        if (axis_rx_ready && axis_rx_valid) begin
          if (dss_rx_cntr == 0) begin
            dss_state   <= DSS_STOP;
          end else begin
            dss_state   <= DSS_RREP;
          end
          dss_rx_cntr  <= dss_rx_cntr - 1;
        end

        if (axis_tx_ready && axis_tx_valid) begin
          out_data      <= axis_tx_data;
          dss_last_tx   <= axis_tx_last;

          if (dss_state == DSS_IDLE) begin
            dss_state     <= DSS_START;
            i2c_bus_sel   <= axis_tx_user[0];
            dss_rx_cntr   <= axis_tx_user[RD_BITS_MAX:1];
          end else begin
            dss_state     <= DSS_TACK;
          end
        end

   end
  end
end


endmodule
