//
// Copyright (c) 2016-2020 Fairwaves, Inc.
// SPDX-License-Identifier: CERN-OHL-W-2.0
//

module ram32xsp #(
    parameter WIDTH = 8
)(
    input              wclk,
    input              we,
    input [4:0]        addr,
    input  [WIDTH-1:0] datai,
    output [WIDTH-1:0] datao
);

`ifdef SYM
// Make debug friendly

reg [WIDTH-1:0] r0;
reg [WIDTH-1:0] r1;
reg [WIDTH-1:0] r2;
reg [WIDTH-1:0] r3;
reg [WIDTH-1:0] r4;
reg [WIDTH-1:0] r5;
reg [WIDTH-1:0] r6;
reg [WIDTH-1:0] r7;
reg [WIDTH-1:0] r8;
reg [WIDTH-1:0] r9;
reg [WIDTH-1:0] r10;
reg [WIDTH-1:0] r11;
reg [WIDTH-1:0] r12;
reg [WIDTH-1:0] r13;
reg [WIDTH-1:0] r14;
reg [WIDTH-1:0] r15;
reg [WIDTH-1:0] r16;
reg [WIDTH-1:0] r17;
reg [WIDTH-1:0] r18;
reg [WIDTH-1:0] r19;
reg [WIDTH-1:0] r20;
reg [WIDTH-1:0] r21;
reg [WIDTH-1:0] r22;
reg [WIDTH-1:0] r23;
reg [WIDTH-1:0] r24;
reg [WIDTH-1:0] r25;
reg [WIDTH-1:0] r26;
reg [WIDTH-1:0] r27;
reg [WIDTH-1:0] r28;
reg [WIDTH-1:0] r29;
reg [WIDTH-1:0] r30;
reg [WIDTH-1:0] r31;

always @(posedge wclk) begin
  if (we) begin
    case (addr)
      0:  r0 <= datai;
      1:  r1 <= datai;
      2:  r2 <= datai;
      3:  r3 <= datai;
      4:  r4 <= datai;
      5:  r5 <= datai;
      6:  r6 <= datai;
      7:  r7 <= datai;
      8:  r8 <= datai;
      9:  r9 <= datai;
      10: r10<= datai;
      11: r11<= datai;
      12: r12<= datai;
      13: r13<= datai;
      14: r14<= datai;
      15: r15<= datai;
      16: r16<= datai;
      17: r17<= datai;
      18: r18<= datai;
      19: r19<= datai;
      20: r20<= datai;
      21: r21<= datai;
      22: r22<= datai;
      23: r23<= datai;
      24: r24<= datai;
      25: r25<= datai;
      26: r26<= datai;
      27: r27<= datai;
      28: r28<= datai;
      29: r29<= datai;
      30: r30<= datai;
      31: r31<= datai;
    endcase
  end
end

assign datao = 
    (addr == 0) ? r0 :
    (addr == 1) ? r1 :
    (addr == 2) ? r2 :
    (addr == 3) ? r3 :
    (addr == 4) ? r4 :
    (addr == 5) ? r5 :
    (addr == 6) ? r6 :
    (addr == 7) ? r7 :
    (addr == 8) ? r8 :
    (addr == 9) ? r9 :
    (addr == 10) ? r10 :
    (addr == 11) ? r11 :
    (addr == 12) ? r12 :
    (addr == 13) ? r13 :
    (addr == 14) ? r14 :
    (addr == 15) ? r15 :
    (addr == 16) ? r16 :
    (addr == 17) ? r17 :
    (addr == 18) ? r18 :
    (addr == 19) ? r19 :
    (addr == 20) ? r20 :
    (addr == 21) ? r21 :
    (addr == 22) ? r22 :
    (addr == 23) ? r23 :
    (addr == 24) ? r24 :
    (addr == 25) ? r25 :
    (addr == 26) ? r26 :
    (addr == 27) ? r27 :
    (addr == 28) ? r28 :
    (addr == 29) ? r29 :
    (addr == 30) ? r30 :
                   r31;


`else
localparam COUNT = (WIDTH + 7) / 8;

wire [8*COUNT-1:0] xdatao;
assign datao = xdatao[WIDTH-1:0];

wire [8*COUNT-1:0] xdatai = datai;

genvar i;
generate
for (i = 0; i < COUNT; i=i+1) begin: part

RAM32M #(
  .INIT_A(64'h0000000000000000), // Initial contents of A Port
  .INIT_B(64'h0000000000000000), // Initial contents of B Port
  .INIT_C(64'h0000000000000000), // Initial contents of C Port
  .INIT_D(64'h0000000000000000)  // Initial contents of D Port
) RAM32X8SP (
  .DOA(xdatao[8*i+1:8*i+0]),
  .DOB(xdatao[8*i+3:8*i+2]),
  .DOC(xdatao[8*i+5:8*i+4]),
  .DOD(xdatao[8*i+7:8*i+6]),

  .ADDRA(addr),
  .ADDRB(addr),
  .ADDRC(addr),
  .ADDRD(addr),

  .DIA(xdatai[8*i+1:8*i+0]),
  .DIB(xdatai[8*i+3:8*i+2]),
  .DIC(xdatai[8*i+5:8*i+4]),
  .DID(xdatai[8*i+7:8*i+6]),

  .WCLK(wclk),
  .WE(we)
);

end
endgenerate

`endif


endmodule
