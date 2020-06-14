//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//
// Half duplex UART 
//

module uart_smartcard #(
    parameter CLK_DIV = 372,
    parameter BITS_SAMPLE = 3,
    parameter CLK_DIV_BITS = 12,
    parameter PARITY_ODD = 0
)(
    input reset,
    input baseclk,

    input  rxd,
    output txd_oen,
    
    input  [7:0] tx_data,
    input        tx_valid,
    output       tx_ready,
    
    output [7:0] rx_data,
    output       rx_valid,
    input        rx_ready,
    
    output       parity_error
);

//
// SMART CARD UART FORMAT
// 1 START
// 8 DATA
// 1 PARITY
// 2 STOP (with ACK/NACK and retransmition)
//
// Total 12 bits per byte

(* ASYNC_REG = "TRUE" *) reg [BITS_SAMPLE - 1:0] rxd_sampled;
always @(posedge baseclk) begin
  if (reset) begin
    rxd_sampled <= ((1 << BITS_SAMPLE) - 1);
  end else begin
    rxd_sampled <= { rxd_sampled[BITS_SAMPLE - 2:0], rxd };
  end
end

wire sampled_one  = (rxd_sampled == ((1 << BITS_SAMPLE) - 1));
wire sampled_zero = (rxd_sampled == 0);

reg parity;  // Parity bit calculation

localparam MODE_IDLE = 2'b00;
localparam MODE_TX   = 2'b01;
localparam MODE_RX   = 2'b11;

reg [1:0] mode;    // Half-duplex direction

reg [CLK_DIV_BITS - 1:0] clk_div;

reg [7:0] retransmition_byte; // Retransmit byte
reg [8:0] tx_byte;
reg [7:0] rx_byte;            // Byte received

reg [4:0] bit_count;          // Bit count during serialization

reg       rx_valid_reg;

reg       par_err;

assign tx_ready = (mode == MODE_IDLE);
assign txd_oen  = tx_byte[0];

assign rx_data = rx_byte;
assign rx_valid = rx_valid_reg;

assign parity_error = par_err;

// TODO  byte retransmition

wire tx_edge = (bit_count[0] == 1);
wire rx_edge = (bit_count[0] == 0);

////////////////
// LHHL LLL LLH sets up the inverse convention: state L encodes value 1 and moment 2 conveys the 
//              most significant bit (msb first). When decoded by inverse convention, the conveyed byte is equal to '3F'. 
// 
// LHHL HHH LLH sets  up  the  direct  convention:  state  H  encodes  value  1  and  moment  2  conveys  the  
//              least significant bit (lsb first). When decoded by direct convention, the conveyed byte is equal to '3B'. 


always @(posedge baseclk) begin
  if (reset) begin
    mode         <= MODE_IDLE;
    tx_byte[0]   <= 1'b1;
    rx_valid_reg <= 1'b0;
  end else begin
    if (mode == MODE_IDLE) begin
      if (tx_valid) begin
        mode    <= MODE_TX;
        tx_byte <= { tx_data, 1'b0 };
      end else if (sampled_zero) begin
        rx_valid_reg <= 1'b0;
        mode         <= MODE_RX;
        par_err      <= 0;  
      end
      
      bit_count <= 0;
      clk_div   <= 0;
      parity    <= PARITY_ODD;
    
    end else begin
      if (clk_div == ((CLK_DIV/2) - 1)) begin
      
        if (mode == MODE_TX) begin
          if (tx_edge && bit_count[4:1] < 8) begin
            tx_byte[7:0] <= tx_byte[8:1];
            parity       <= parity ^ tx_byte[1];
          end else if (tx_edge && bit_count[4:1] == 8) begin
            tx_byte[0]   <= parity;
          end else if (tx_edge && bit_count[4:1] == 9) begin
            tx_byte[0]   <= 1'b1;
          end else if (tx_edge && bit_count[4:1] == 10) begin
            par_err      <= sampled_zero;
          end else if (tx_edge && ~par_err && bit_count[4:1] == 11) begin
            mode <= MODE_IDLE;
          end else if (tx_edge /* && par_err && bit_count[4:1] == 13 */) begin
            // TODO: retransmition
            mode <= MODE_IDLE;
          end
        end else if (mode == MODE_RX) begin
          if (rx_edge && (bit_count[4:1] < 9)) begin
            rx_byte <= { sampled_one, rx_byte[7:1] };
            parity  <= parity ^ sampled_one;
          end else if (rx_edge && (bit_count[4:1] == 9)) begin
            if (parity != sampled_one) begin
              // TODO: parity error notification
              par_err <= 1'b1;
            end
            rx_valid_reg <= 1'b1;
          end else if (rx_edge && (bit_count[4:1] == 11)) begin
            mode <= MODE_IDLE;
          end
        end
        
        bit_count <= bit_count + 1;
        clk_div   <= 0;
      end else if (mode != MODE_IDLE) begin
        clk_div <= clk_div + 1;
      end
    end
    
    if (rx_valid_reg && rx_ready) begin
      rx_valid_reg <= 1'b0;
    end
  end
end


endmodule
