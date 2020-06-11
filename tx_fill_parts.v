//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module tx_fill_parts #(
    parameter WIDTH = 16
)(
    input reset,
    input s_ul_clk,

    input               incb_valid,
    output              incb_ready,
    input  [WIDTH-1:0]  incb_size,
    input  [4:0]        incb_idx,

    input               decb_valid,
    input  [WIDTH-1:0]  decb_size,
    input  [4:0]        decb_idx,

    input  [4:0]        cur_buf_num,
    output              inc_buf
);

reg [4:0] buf_max_written;

localparam ST_IDLE  = 0;
localparam ST_CHECK = 1;

reg       state;


wire   [WIDTH-1:0] ram_out;
assign incb_ready = ~decb_valid && (state == ST_IDLE);

wire   inc_cycle  = incb_valid && incb_ready;
wire   dec_cycle  = decb_valid;
wire   check_cycle= ~dec_cycle && ~inc_cycle;

wire [4:0]  ram_addr = (dec_cycle) ? decb_idx :
            (check_cycle) ? cur_buf_num /*buf_last_commited*/ : incb_idx;
wire        ram_we   = inc_cycle || dec_cycle;

wire [WIDTH-1:0]  writeback_dec = ram_out - decb_size;
wire [WIDTH-1:0]  writeback = (inc_cycle) ? incb_size : writeback_dec;

//assign      decb_last = (writeback_dec == 0);

// FIXME to reg!!
assign inc_buf = ~dec_cycle && ~dec_cycle && (state == ST_CHECK) && (ram_out == 0);

always @(posedge s_ul_clk) begin
  if (reset) begin
    //buf_last_commited <= 5'b0_0000;
    buf_max_written   <= 5'b1_1111;
    state             <= ST_IDLE;
  end else begin
    if (dec_cycle) begin
      state   <= ST_CHECK;
    end else if (inc_cycle) begin
      buf_max_written <= incb_idx;
    end else if (state == ST_CHECK) begin // check_cycle
      if (ram_out == 0) begin
        // Buffer has been filled
        //buf_last_commited <= buf_last_commited + 1'b1;
        if (buf_max_written == cur_buf_num/*buf_last_commited*/)
          state <= ST_IDLE;
      end else begin
        state   <= ST_IDLE;
      end
    end

  end
end

ram32xsp #(.WIDTH(WIDTH)) storage(
    .wclk(s_ul_clk),
    .we(ram_we),
    .addr(ram_addr),
    .datai(writeback),
    .datao(ram_out)
);

endmodule

