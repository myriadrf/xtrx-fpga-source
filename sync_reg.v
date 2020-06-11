//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module sync_reg #(
   parameter INIT         = 0,
   parameter ASYNC_RESET  = 0
) (
   input  clk,
   input  rst,
   input  in,
   output out

);

(* ASYNC_REG = "TRUE" *) reg sync1;
(* ASYNC_REG = "TRUE" *) reg sync2;

assign out = sync2;

generate
if (ASYNC_RESET) begin
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      sync1 <= INIT;
      sync2 <= INIT;
    end else begin
      sync1 <= in;
      sync2 <= sync1;
    end
  end
end else begin
  always @(posedge clk) begin
    if (rst) begin
      sync1 <= INIT;
      sync2 <= INIT;
    end else begin
      sync1 <= in;
      sync2 <= sync1;
    end
  end
end
endgenerate

endmodule

