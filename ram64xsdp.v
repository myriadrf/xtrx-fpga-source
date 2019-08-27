module ram64xsdp #(
    parameter WIDTH = 3
)(
   input        wclk,
   input        we,
   input [5:0]  waddr,
   input [WIDTH-1:0]  datai,

   input [5:0]  raddr,
   output [WIDTH-1:0]  datao
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
reg [WIDTH-1:0] r32;
reg [WIDTH-1:0] r33;
reg [WIDTH-1:0] r34;
reg [WIDTH-1:0] r35;
reg [WIDTH-1:0] r36;
reg [WIDTH-1:0] r37;
reg [WIDTH-1:0] r38;
reg [WIDTH-1:0] r39;
reg [WIDTH-1:0] r40;
reg [WIDTH-1:0] r41;
reg [WIDTH-1:0] r42;
reg [WIDTH-1:0] r43;
reg [WIDTH-1:0] r44;
reg [WIDTH-1:0] r45;
reg [WIDTH-1:0] r46;
reg [WIDTH-1:0] r47;
reg [WIDTH-1:0] r48;
reg [WIDTH-1:0] r49;
reg [WIDTH-1:0] r50;
reg [WIDTH-1:0] r51;
reg [WIDTH-1:0] r52;
reg [WIDTH-1:0] r53;
reg [WIDTH-1:0] r54;
reg [WIDTH-1:0] r55;
reg [WIDTH-1:0] r56;
reg [WIDTH-1:0] r57;
reg [WIDTH-1:0] r58;
reg [WIDTH-1:0] r59;
reg [WIDTH-1:0] r60;
reg [WIDTH-1:0] r61;
reg [WIDTH-1:0] r62;
reg [WIDTH-1:0] r63;

always @(posedge wclk) begin
  if (we) begin
    case (waddr)
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
      32: r32<= datai;
      33: r33<= datai;
      34: r34<= datai;
      35: r35<= datai;
      36: r36<= datai;
      37: r37<= datai;
      38: r38<= datai;
      39: r39<= datai;
      40: r40<= datai;
      41: r41<= datai;
      42: r42<= datai;
      43: r43<= datai;
      44: r44<= datai;
      45: r45<= datai;
      46: r46<= datai;
      47: r47<= datai;
      48: r48<= datai;
      49: r49<= datai;
      50: r50<= datai;
      51: r51<= datai;
      52: r52<= datai;
      53: r53<= datai;
      54: r54<= datai;
      55: r55<= datai;
      56: r56<= datai;
      57: r57<= datai;
      58: r58<= datai;
      59: r59<= datai;
      60: r60<= datai;
      61: r61<= datai;
      62: r62<= datai;
      63: r63<= datai;
    endcase
  end
end

assign datao =
    (raddr == 0) ? r0 :
    (raddr == 1) ? r1 :
    (raddr == 2) ? r2 :
    (raddr == 3) ? r3 :
    (raddr == 4) ? r4 :
    (raddr == 5) ? r5 :
    (raddr == 6) ? r6 :
    (raddr == 7) ? r7 :
    (raddr == 8) ? r8 :
    (raddr == 9) ? r9 :
    (raddr == 10) ? r10 :
    (raddr == 11) ? r11 :
    (raddr == 12) ? r12 :
    (raddr == 13) ? r13 :
    (raddr == 14) ? r14 :
    (raddr == 15) ? r15 :
    (raddr == 16) ? r16 :
    (raddr == 17) ? r17 :
    (raddr == 18) ? r18 :
    (raddr == 19) ? r19 :
    (raddr == 20) ? r20 :
    (raddr == 21) ? r21 :
    (raddr == 22) ? r22 :
    (raddr == 23) ? r23 :
    (raddr == 24) ? r24 :
    (raddr == 25) ? r25 :
    (raddr == 26) ? r26 :
    (raddr == 27) ? r27 :
    (raddr == 28) ? r28 :
    (raddr == 29) ? r29 :
    (raddr == 30) ? r30 :
    (raddr == 31) ? r31 :
    (raddr == 32) ? r32 :
    (raddr == 33) ? r33 :
    (raddr == 34) ? r34 :
    (raddr == 35) ? r35 :
    (raddr == 36) ? r36 :
    (raddr == 37) ? r37 :
    (raddr == 38) ? r38 :
    (raddr == 39) ? r39 :
    (raddr == 40) ? r40 :
    (raddr == 41) ? r41 :
    (raddr == 42) ? r42 :
    (raddr == 43) ? r43 :
    (raddr == 44) ? r44 :
    (raddr == 45) ? r45 :
    (raddr == 46) ? r46 :
    (raddr == 47) ? r47 :
    (raddr == 48) ? r48 :
    (raddr == 49) ? r49 :
    (raddr == 50) ? r50 :
    (raddr == 51) ? r51 :
    (raddr == 52) ? r52 :
    (raddr == 53) ? r53 :
    (raddr == 54) ? r54 :
    (raddr == 55) ? r55 :
    (raddr == 56) ? r56 :
    (raddr == 57) ? r57 :
    (raddr == 58) ? r58 :
    (raddr == 59) ? r59 :
    (raddr == 60) ? r60 :
    (raddr == 61) ? r61 :
    (raddr == 62) ? r62 :
                    r63;

`else
localparam COUNT = (WIDTH + 2) / 3;

wire [3*COUNT-1:0] xdatao;
assign datao = xdatao[WIDTH-1:0];

wire [3*COUNT-1:0] xdatai = datai;

genvar i;
generate
for (i = 0; i < COUNT; i=i+1) begin: part

RAM64M #(
  .INIT_A(64'h0000000000000000), // Initial contents of A Port
  .INIT_B(64'h0000000000000000), // Initial contents of B Port
  .INIT_C(64'h0000000000000000), // Initial contents of C Port
  .INIT_D(64'h0000000000000000)  // Initial contents of D Port
) RAM64X6SDP (
  .DOA(xdatao[3*i+0]),
  .DOB(xdatao[3*i+1]),
  .DOC(xdatao[3*i+2]),
  .DOD(),

  .ADDRA(raddr),
  .ADDRB(raddr),
  .ADDRC(raddr),
  .ADDRD(waddr),

  .DIA(xdatai[3*i+0]),
  .DIB(xdatai[3*i+1]),
  .DIC(xdatai[3*i+2]),
  .DID(2'b0),

  .WCLK(wclk),
  .WE(we)
);

end
endgenerate
`endif


endmodule
