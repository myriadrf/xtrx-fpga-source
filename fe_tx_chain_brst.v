module fe_tx_chain_brst #(
    parameter LOW_ADDDR_BITS = 13,
    parameter TS_BITS        = 30
)(
    input mclk,
    input arst,
    input mode_siso,
    input mode_repeat,
    input [2:0] inter_rate,

    // LMS7 if
    output [11:0] out_sdr_ai,
    output [11:0] out_sdr_aq,
    output [11:0] out_sdr_bi,
    output [11:0] out_sdr_bq,
    output        out_strobe,

    // Output overrun notification
    // TODO
    output [1:0]                debug_fe_state,
    output [LOW_ADDDR_BITS-1:0] debug_rd_addr,

    output                      ts_rd_addr_inc,
    output [TS_BITS-1:0]        ts_rd_addr_late_samples,

    output                      ts_rd_addr_processed_inc,
    input                       ts_rd_valid,   // Valid start time & No of samples
    input [TS_BITS-1:0]         ts_rd_start,
    input [LOW_ADDDR_BITS-1:0]  ts_rd_samples,
    output [TS_BITS-1:0]        ts_current,

    //FIFO RAM iface
    output                      fifo_rd_en,
    output [LOW_ADDDR_BITS-1:0] fifo_rd_addr,
    input  [47:0]               fifo_rd_data,


    // Output current read addr (with 1 extra MSB)
    input                       out_rd_clk,
    input                       out_rd_rst,
    output [LOW_ADDDR_BITS:4]   out_rd_addr
);

wire               out_iq_sel;

wire               overrun;


wire               fifo_tready;
wire               fifo_tvalid;

lms7_tx_frm_brst_ex lms7_tx_frm_brst_ex(
   .rst(arst),

   // LMS7
   .out_sdr_ai(out_sdr_ai),
   .out_sdr_aq(out_sdr_aq),
   .out_sdr_bi(out_sdr_bi),
   .out_sdr_bq(out_sdr_bq),
   .out_strobe(out_strobe),
   .mclk(mclk),

   // FIFO (RAM)
   .fifo_tdata(fifo_rd_data),
   .fifo_tvalid(fifo_tvalid),
   .fifo_tready(fifo_tready),

   .single_ch_mode(mode_siso),
   .inter_rate(inter_rate)
);

wire   fifo_rd_last;
wire   blk_in_time;

reg blk_in_time_reg;
reg blk_in_time_reg_2;


localparam ST_WAIT_TS         = 0;
localparam ST_WAIT_BURST      = 1;
localparam ST_INBURST         = 2;

localparam ST_REPEAT          = 3; // repeat mode in functional generator

reg [1:0] state;

assign debug_fe_state = state;


reg ts_rd_addr_inc_reg;
assign ts_rd_addr_inc = ts_rd_addr_inc_reg;


wire clk_iter_strobe = fifo_tready;
assign fifo_rd_en  = (state != ST_WAIT_TS) && (clk_iter_strobe);

reg [LOW_ADDDR_BITS-1:0] cur_sample_in_burst;

wire prev_last_sample_in_burst = (cur_sample_in_burst == 2);
reg  last_sample_in_burst;

reg repeat_reset;

assign fifo_tvalid = (state == ST_REPEAT || state == ST_INBURST);


wire fifo_rd_addr_inc = (state == ST_REPEAT && fifo_tready) ||
                        (state == ST_WAIT_BURST && blk_in_time_reg && clk_iter_strobe) ||
			(state == ST_INBURST && (fifo_tready) && (~last_sample_in_burst || ts_rd_valid && blk_in_time_reg));


assign ts_rd_addr_processed_inc = (state == ST_INBURST) && last_sample_in_burst && fifo_tready;


always @(posedge mclk) begin
  if (arst) begin
    ts_rd_addr_inc_reg      <= 1'b0;
    cur_sample_in_burst     <= 1'b0;
    last_sample_in_burst    <= 1'b0;
    repeat_reset            <= 1'b0;

    if (mode_repeat) begin
      state               <= ST_REPEAT;
      cur_sample_in_burst <= ts_rd_samples;
    end else begin
      state               <= ST_WAIT_TS;
    end
  end else begin

    ts_rd_addr_inc_reg <= ((state == ST_WAIT_BURST) && blk_in_time_reg && clk_iter_strobe) ||
                          ((state == ST_INBURST) && fifo_tready && last_sample_in_burst && ts_rd_valid && blk_in_time_reg);

    case (state)
      ST_WAIT_TS: begin
        if (ts_rd_valid && clk_iter_strobe) begin
          state               <= ST_WAIT_BURST;
          cur_sample_in_burst <= ts_rd_samples;
        end
      end

      ST_WAIT_BURST: begin
        if (blk_in_time_reg && clk_iter_strobe) begin
          state                  <= ST_INBURST;
        end
      end

      ST_INBURST: begin
        if (fifo_tready) begin
          if (last_sample_in_burst) begin
            if (ts_rd_valid) begin
              cur_sample_in_burst <= ts_rd_samples;

              if (~blk_in_time_reg) begin
                state             <= ST_WAIT_BURST;
              end
            end else begin
              state               <= ST_WAIT_TS;
            end

            last_sample_in_burst <= 1'b0;
          end else begin
            cur_sample_in_burst  <= cur_sample_in_burst - 1'b1;
            last_sample_in_burst <= prev_last_sample_in_burst;
          end
        end
      end

      // Nothing to do in repeat mode
      ST_REPEAT: begin
        if (fifo_tready) begin
          if (last_sample_in_burst) begin
            cur_sample_in_burst  <= ts_rd_samples;
            last_sample_in_burst <= 1'b0;
          end else begin
            cur_sample_in_burst  <= cur_sample_in_burst - 1'b1;
            last_sample_in_burst <= prev_last_sample_in_burst;
          end
        end

        repeat_reset         <= (fifo_tready && prev_last_sample_in_burst);
      end

    endcase
  end
end

assign debug_rd_addr = fifo_rd_addr;

cross_counter #(
  .WIDTH(LOW_ADDDR_BITS),
  .GRAY_BITS(3+4),
  .OUT_WIDTH(LOW_ADDDR_BITS+1),
  .OUT_LOWER_SKIP(4)
) sym_addr (
   .inrst(arst | repeat_reset),
   .inclk(mclk),
   .incmdvalid(fifo_rd_addr_inc),
   .incmdinc(1'b1),
   .incnt(fifo_rd_addr),

   .outrst(out_rd_rst),
   .outclk(out_rd_clk),
   .outcnt(out_rd_addr)
);


reg [TS_BITS-1:0] ts_current_reg;
assign ts_current = ts_current_reg;

always @(posedge mclk) begin
  if (arst) begin
    ts_current_reg <= 0;
  end else begin
    if (clk_iter_strobe) begin
      ts_current_reg <= ts_current_reg + 1;
    end
  end
end

wire [TS_BITS-1:0] diff_v = ts_current - ts_rd_start + 1'b1;
assign ts_rd_addr_late_samples = diff_v;


always @(posedge mclk) begin
  if (arst) begin
    blk_in_time_reg   <= 0;
  end else begin
    if (clk_iter_strobe) begin
      blk_in_time_reg   <= ~diff_v[TS_BITS-1];
    end
  end
end

assign blk_in_time   = blk_in_time_reg;


endmodule
