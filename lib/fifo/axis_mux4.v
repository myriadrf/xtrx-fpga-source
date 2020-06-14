module axis_mux4(
    input         s_axis_clk,
    input         s_arstn,

    input         m_axis_tready,
    output [63:0] m_axis_tdata,
    output [7:0]  m_axis_tkeep,
    output        m_axis_tlast,
    output        m_axis_tvalid,

    output        s0_axis_tready,
    input  [63:0] s0_axis_tdata,
    input  [7:0]  s0_axis_tkeep,
    input         s0_axis_tlast,
    input         s0_axis_tvalid,

    output        s1_axis_tready,
    input  [63:0] s1_axis_tdata,
    input  [7:0]  s1_axis_tkeep,
    input         s1_axis_tlast,
    input         s1_axis_tvalid,

    output        s2_axis_tready,
    input  [63:0] s2_axis_tdata,
    input  [7:0]  s2_axis_tkeep,
    input         s2_axis_tlast,
    input         s2_axis_tvalid,

    output        s3_axis_tready,
    input  [63:0] s3_axis_tdata,
    input  [7:0]  s3_axis_tkeep,
    input         s3_axis_tlast,
    input         s3_axis_tvalid
);


localparam MUX_S0   = 2'h0;
localparam MUX_S1   = 2'h1;
localparam MUX_S2   = 2'h2;
localparam MUX_S3   = 2'h3;

reg [1:0] state;

assign m_axis_tdata = (state == MUX_S0) ? s0_axis_tdata :
                      (state == MUX_S1) ? s1_axis_tdata :
                      (state == MUX_S2) ? s2_axis_tdata :
                    /*(state == MUX_S3) ?*/ s3_axis_tdata;

assign m_axis_tkeep = (state == MUX_S0) ? s0_axis_tkeep :
                      (state == MUX_S1) ? s1_axis_tkeep :
                      (state == MUX_S2) ? s2_axis_tkeep :
                    /*(state == MUX_S3) ?*/ s3_axis_tkeep;

assign m_axis_tvalid = (state == MUX_S0) ? s0_axis_tvalid :
                       (state == MUX_S1) ? s1_axis_tvalid :
                       (state == MUX_S2) ? s2_axis_tvalid :
                       (state == MUX_S3) ? s3_axis_tvalid :
                                                      1'b0;

assign m_axis_tlast = (state == MUX_S0) ? s0_axis_tlast :
                      (state == MUX_S1) ? s1_axis_tlast :
                      (state == MUX_S2) ? s2_axis_tlast :
                    /*(state == MUX_S3) ?*/ s3_axis_tlast;

assign s0_axis_tready = (state == MUX_S0) ? m_axis_tready : 1'b0;
assign s1_axis_tready = (state == MUX_S1) ? m_axis_tready : 1'b0;
assign s2_axis_tready = (state == MUX_S2) ? m_axis_tready : 1'b0;
assign s3_axis_tready = (state == MUX_S3) ? m_axis_tready : 1'b0;

wire [2:0] sel_prio_state = (s0_axis_tvalid) ? {1'b1, MUX_S0 } :
                            (s1_axis_tvalid) ? {1'b1, MUX_S1 } :
                            (s2_axis_tvalid) ? {1'b1, MUX_S2 } :
                            (s3_axis_tvalid) ? {1'b1, MUX_S3 } : {1'b0, MUX_S0 };

reg started;
wire last_transfer = m_axis_tready && m_axis_tvalid && m_axis_tlast;

always @(posedge s_axis_clk) begin
  if (~s_arstn) begin
    state   <= MUX_S0;
    started <= 1'b0;
  end else begin
    if (~started) begin
      if (m_axis_tvalid) begin
        started <= 1'b1;
      end else begin
        state   <= sel_prio_state[1:0];
      end
    end
    if (last_transfer) begin
      state   <= sel_prio_state[1:0];
      started <= (state != sel_prio_state[1:0]) && sel_prio_state[2];
    end
  end
end


endmodule
