module axis_atomic_fo #(
    parameter CHA_BITS        = 8,
    parameter CHB_BITS        = 8
)(
    input reset,
    input s_ul_clk,

    output s_axis_comb_tready,
    input  s_axis_comb_tvalid,
    input [CHA_BITS+CHB_BITS-1:0] s_axis_comb_tdata,
    input [1:0] s_axis_comb_tuser,

    input  m_axis_cha_tready,
    output reg m_axis_cha_tvalid,
    output reg [CHA_BITS-1:0] m_axis_cha_tdata,

    input  m_axis_chb_tready,
    output reg m_axis_chb_tvalid,
    output reg [CHB_BITS-1:0] m_axis_chb_tdata
);

assign s_axis_comb_tready = ~(m_axis_cha_tvalid || m_axis_chb_tvalid);

always @(posedge s_ul_clk) begin
  if (reset) begin
    m_axis_cha_tvalid <= 1'b0;
    m_axis_chb_tvalid <= 1'b0;
  end else begin
    if (s_axis_comb_tready && s_axis_comb_tvalid) begin
      m_axis_cha_tvalid <= s_axis_comb_tuser[0];
      m_axis_cha_tdata  <= s_axis_comb_tdata[CHA_BITS-1:0];
      m_axis_chb_tvalid <= s_axis_comb_tuser[1];
      m_axis_chb_tdata  <= s_axis_comb_tdata[CHB_BITS-1+CHA_BITS:CHA_BITS];
    end

    if (m_axis_cha_tvalid && m_axis_chb_tready)
      m_axis_cha_tvalid <= 1'b0;

    if (m_axis_chb_tvalid && m_axis_chb_tready)
      m_axis_chb_tvalid <= 1'b0;

  end
end

endmodule

