//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module cross_counter #(
   parameter WIDTH = 8,
   parameter GRAY_BITS = WIDTH,
   parameter OUT_WIDTH = WIDTH,
   parameter OUT_LOWER_SKIP = 0,
   parameter OUT_RESET_ASYNC = 0,
   parameter OUT_PIPELINED = 0
)(
   input                                 inrst,
   input                                 inclk,
   input                                 incmdvalid,
   input                                 incmdinc,
   output [WIDTH - 1:0]                  incnt,

   input                                 outclk,
   input                                 outrst,
   output [OUT_WIDTH - 1:OUT_LOWER_SKIP] outcnt
);

genvar i;

reg [WIDTH - 1:0] counter;

reg  [GRAY_BITS - 1:OUT_LOWER_SKIP] gray_encoded;
wire [GRAY_BITS - 1:OUT_LOWER_SKIP] sync_out;

wire [GRAY_BITS - 1:OUT_LOWER_SKIP] gcode =
	counter[GRAY_BITS - 1:OUT_LOWER_SKIP] ^ counter[GRAY_BITS - 1:OUT_LOWER_SKIP+1];


always @(posedge inclk) begin
  if (inrst) begin
    counter      <= 0;
    gray_encoded <= 0;
  end else begin
    if (incmdvalid) begin
      if (incmdinc) begin
        counter <= counter + 1;
      end else begin
        counter <= counter - 1;
      end
    end
    gray_encoded <= gcode;
  end
end

assign incnt = counter;


generate
  for (i = OUT_LOWER_SKIP; i < GRAY_BITS; i=i+1) begin: forreg
    sync_reg #(.ASYNC_RESET(OUT_RESET_ASYNC)) sreg (
      .clk(outclk),
      .rst(outrst),
      .in(gray_encoded[i]),
      .out(sync_out[i])
    );
  end
endgenerate


wire [GRAY_BITS - 1:OUT_LOWER_SKIP] outgray;
assign outgray[GRAY_BITS - 1] = sync_out[GRAY_BITS - 1];

generate
for (i = GRAY_BITS - 1; i > OUT_LOWER_SKIP; i=i-1) begin
  assign outgray[i - 1] = outgray[i] ^ sync_out[i - 1];
end
endgenerate



generate
if (OUT_PIPELINED || OUT_WIDTH != GRAY_BITS) begin
  reg [OUT_WIDTH - 1:OUT_LOWER_SKIP] oval;
  assign outcnt = oval;

  if (OUT_RESET_ASYNC) begin
    always @(posedge outclk or posedge outrst) begin
      if (outrst) begin
        oval[GRAY_BITS - 1:OUT_LOWER_SKIP] <= 0;
      end else begin
        oval[GRAY_BITS - 1:OUT_LOWER_SKIP] <= outgray[GRAY_BITS - 1:OUT_LOWER_SKIP];
      end
    end
  end else begin
    always @(posedge outclk) begin
      if (outrst) begin
        oval[GRAY_BITS - 1:OUT_LOWER_SKIP] <= 0;
      end else begin
        oval[GRAY_BITS - 1:OUT_LOWER_SKIP] <= outgray[GRAY_BITS - 1:OUT_LOWER_SKIP];
      end
    end
  end

  if (OUT_WIDTH != GRAY_BITS) begin
    wire wrap_pos = (oval[GRAY_BITS - 1:OUT_LOWER_SKIP] > outgray[GRAY_BITS - 1:OUT_LOWER_SKIP]);

    if (OUT_RESET_ASYNC) begin
      always @(posedge outclk or posedge outrst) begin
        if (outrst) begin
          oval[OUT_WIDTH - 1:GRAY_BITS]      <= 0;
        end else begin
          oval[OUT_WIDTH - 1:GRAY_BITS]      <= oval[OUT_WIDTH - 1:GRAY_BITS] + wrap_pos;
        end
      end
    end else begin
      always @(posedge outclk) begin
        if (outrst) begin
          oval[OUT_WIDTH - 1:GRAY_BITS]      <= 0;
        end else begin
          oval[OUT_WIDTH - 1:GRAY_BITS]      <= oval[OUT_WIDTH - 1:GRAY_BITS] + wrap_pos;
        end
      end
    end
  end
end else begin
  assign outcnt = outgray[OUT_WIDTH - 1:OUT_LOWER_SKIP];
end
endgenerate


endmodule
