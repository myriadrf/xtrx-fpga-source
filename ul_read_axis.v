//
// Sergey Kostanbaev 2016
//
// UL GPIO 32bit
//       READ
// x: IN DATA (not sampled)

module ul_read_axis #(
    parameter DATA_WIDTH = 32,
    parameter NBITS      = 4,
    parameter N = (1 << NBITS)
)(
    // UL clocks
    input                         s_ul_clk,
    input                         s_ul_aresetn,

    // UL Read address channel 0
    input  [NBITS - 1:0]          s_ul_araddr,
    input                         s_ul_arvalid,
    output                        s_ul_arready,
    // UL Write data channel 0 signals
    output reg [DATA_WIDTH - 1:0] s_ul_rdata,
    output reg                    s_ul_rvalid,
    input                         s_ul_rready,

    // read port 0..N-1
    output reg [N - 1:0]          axis_port_ready,
    input  [N - 1:0]              axis_port_valid,
    input  [DATA_WIDTH*N - 1:0]   axis_port_data,

    output [NBITS - 1:0]          axis_port_addr,
    output                        axis_port_addr_valid
);


reg [NBITS - 1:0]       selector;
wire [DATA_WIDTH - 1:0] axis_data;

genvar i;
generate
for (i = 0; i < DATA_WIDTH; i=i+1) begin: gen
  assign axis_data[i] = axis_port_data[DATA_WIDTH*selector + i];
end
endgenerate

wire axis_valid = axis_port_valid[selector];

localparam ST_WAIT_READ_ADDR = 1'b0;
localparam ST_WAIT_TRANSFER  = 1'b1;

reg state;

assign s_ul_arready = ((s_ul_rvalid && s_ul_rready) || ~s_ul_rvalid);

always @(posedge s_ul_clk) begin
  if (~s_ul_aresetn) begin
    axis_port_ready <= 0;
    s_ul_rvalid     <= 0;
    selector        <= 0;
    state           <= ST_WAIT_READ_ADDR;
  end else begin
    if (state == ST_WAIT_READ_ADDR) begin
      if (s_ul_arvalid && s_ul_arready) begin
        selector                      <= s_ul_araddr;
        state                         <= ST_WAIT_TRANSFER;
        axis_port_ready[s_ul_araddr]  <= 1'b1;
      end

      if (s_ul_rvalid && s_ul_rready) begin
        s_ul_rvalid                  <= 1'b0;
      end
    end else begin
      if (axis_valid) begin
        axis_port_ready <= 0;
        s_ul_rdata      <= axis_data;
        s_ul_rvalid     <= 1'b1;
        state           <= ST_WAIT_READ_ADDR;
      end
    end
  end
end

assign axis_port_addr = selector;
assign axis_port_addr_valid = (state == ST_WAIT_TRANSFER);


endmodule
