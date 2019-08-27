module ul_read_demux_axis #(
    parameter DATA_WIDTH = 32,
    parameter NBITS      = 4
)(
    // UL clocks
    input                         s_ul_clk,
    input                         s_ul_aresetn,

    // UL Read address channel 0
    input  [NBITS - 1:0]          s_ul_araddr,
    input                         s_ul_arvalid,
    output                        s_ul_arready,
    // UL Write data channel 0 signals
    output     [DATA_WIDTH - 1:0] s_ul_rdata,
    output                        s_ul_rvalid,
    input                         s_ul_rready,

    // mem port
    // UL Read address channel 0
    output  [NBITS - 2:0]          m0_ul_araddr,
    output                         m0_ul_arvalid,
    input                          m0_ul_arready,
    // UL Write data channel 0 signals
    input [DATA_WIDTH - 1:0]       m0_ul_rdata,
    input                          m0_ul_rvalid,
    output                         m0_ul_rready,

    // mem port
    // UL Read address channel 0
    output  [NBITS - 2:0]          m1_ul_araddr,
    output                         m1_ul_arvalid,
    input                          m1_ul_arready,
    // UL Write data channel 0 signals
    input [DATA_WIDTH - 1:0]       m1_ul_rdata,
    input                          m1_ul_rvalid,
    output                         m1_ul_rready
);


assign m0_ul_araddr = s_ul_araddr[NBITS - 2:0];
assign m1_ul_araddr = s_ul_araddr[NBITS - 2:0];

assign s_ul_arready = ~s_ul_araddr[NBITS - 1] && m0_ul_arready ||
                       s_ul_araddr[NBITS - 1] && m1_ul_arready;

assign m0_ul_arvalid = ~s_ul_araddr[NBITS - 1] && s_ul_arvalid;
assign m1_ul_arvalid =  s_ul_araddr[NBITS - 1] && s_ul_arvalid;

wire rb_route_port;
wire rb_route_port_valid;


axis_fifo32 #(.WIDTH(1)) routing_fifo (
  .clk(s_ul_clk),
  .axisrst(~s_ul_aresetn),

  .axis_rx_tdata(s_ul_araddr[NBITS - 1]),
  .axis_rx_tvalid(s_ul_arready && s_ul_arvalid),
  .axis_rx_tready(),  //Ignore for now since it's impossible to hold 32 bit queue

  .axis_tx_tdata(rb_route_port),
  .axis_tx_tvalid(rb_route_port_valid),
  .axis_tx_tready(s_ul_rready && s_ul_rvalid),

  .fifo_used(),
  .fifo_empty()
);

assign s_ul_rdata = (rb_route_port) ? m1_ul_rdata : m0_ul_rdata;
assign s_ul_rvalid = rb_route_port_valid && (~rb_route_port && m0_ul_rvalid ||
                                              rb_route_port && m1_ul_rvalid);

assign m0_ul_rready = rb_route_port_valid && ~rb_route_port && s_ul_rready;
assign m1_ul_rready = rb_route_port_valid &&  rb_route_port && s_ul_rready;


endmodule
