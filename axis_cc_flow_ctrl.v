module axis_cc_flow_ctrl(
  input s_axis_clk,
  input s_aresetn,
  input s_axis_valid,
  output s_axis_ready,

  input m_axis_clk,
  input m_aresetn,
  output m_axis_valid,
  input m_axis_ready
);

reg  wa;
wire wb;
wire ra;
reg  rb;

sync_reg s_to_m(
  .clk(m_axis_clk),
  .rst(~m_aresetn),
  .in(wa),
  .out(wb)
);

sync_reg m_to_s(
  .clk(s_axis_clk),
  .rst(~s_aresetn),
  .in(rb),
  .out(ra)
);

assign s_axis_ready = wa ^ ra ^ 1'b1;
assign m_axis_valid = wb ^ rb;

always @(posedge s_axis_clk) begin
  if (~s_aresetn) begin
    wa <= 1'b0;
  end else if (s_axis_valid && s_axis_ready) begin
    wa <= ~wa;
  end
end

always @(posedge m_axis_clk) begin
  if (~m_aresetn) begin
    rb <= 1'b0;
  end else if (m_axis_valid && m_axis_ready) begin
    rb <= ~rb;
  end
end


endmodule
