module int_router #(
    parameter COUNT = 16,
    parameter DELAY_CYCLE = 0
) (
    input clk,
    input reset,

    // PCI-e interface
    input            interrupt_msi_enabled,
    input            interrupt_rdy,

    output reg       interrupt,
    output reg       interrupt_assert,
    output reg [7:0] interrupt_num,

    input            legacy_interrupt_disabled,
    input      [2:0] interrupt_mmenable,

    output     [4:0] cap_interrupt_msgnum,
    output           cap_interrupt_stat,

    // User Interrupt status
    input                 int_stat_ready,
    output                int_stat_valid,
    output [COUNT - 1: 0] int_stat_data,

    // User Interrupt control
    output                int_ctrl_ready,
    input                 int_ctrl_valid,
    input [COUNT - 1: 0]  int_ctrl_data,


    // User Interrupr interfcae
    input  [COUNT - 1:0]  int_valid,
    output [COUNT - 1:0]  int_ready
);
assign cap_interrupt_stat   = 1'b0;

reg [COUNT-1:0] int_en;
wire [31:0] int_active = int_valid & int_en;


wire [4:0] msi_num_x;
wire       msi_num_xval;

wire [31:0] int_active_r;
genvar i;
generate
for (i = 0; i < 32; i=i+1) begin: rev
    assign int_active_r[31-i] = int_active[i];
end
endgenerate

clz #(.B_WIDTH(5)) clz_decode (
  .data(int_active_r),

  .count(msi_num_x),
  .count_nvalid(msi_num_xval)
);
wire [4:0] msi_num = /*(msi_num_xval) ? 0 :*/ msi_num_x;


wire [36:0] msi_msk_and_cap =
  (interrupt_mmenable == 3'b000 && (COUNT > 1))  ? { 5'b00001, 32'hffff_ffff } :
  (interrupt_mmenable == 3'b001 && (COUNT > 2))  ? { 5'b00010, 32'hffff_fffe } :
  (interrupt_mmenable == 3'b010 && (COUNT > 4))  ? { 5'b00100, 32'hffff_fff8 } :
  (interrupt_mmenable == 3'b011 && (COUNT > 8))  ? { 5'b01000, 32'hffff_ff80 } :
  (interrupt_mmenable == 3'b100 && (COUNT > 16)) ? { 5'b10000, 32'hffff_8000 } :
                                                   { COUNT[4:0], 32'h0000_0000 };
assign cap_interrupt_msgnum = msi_msk_and_cap[36:32];
wire [31:0] msi_ready_clean_msk =
  (interrupt_msi_enabled) ? msi_msk_and_cap[31:0] : 32'hffff_ffff;

wire [5:0] msi_num_fit =
  (interrupt_mmenable == 3'b000 && (COUNT > 1))                    ? 6'b1_00000 :
  (interrupt_mmenable == 3'b001 && (COUNT > 2)  && (msi_num > 0))  ? 6'b1_00001 :
  (interrupt_mmenable == 3'b010 && (COUNT > 4)  && (msi_num > 2))  ? 6'b1_00011 :
  (interrupt_mmenable == 3'b011 && (COUNT > 8)  && (msi_num > 6))  ? 6'b1_00111 :
  (interrupt_mmenable == 3'b100 && (COUNT > 16) && (msi_num > 14)) ? 6'b1_01111 :
                                                                     { 1'b0, msi_num };
wire [4:0] msi_num_gen = msi_num_fit[4:0];
wire       msi_no_fit  = msi_num_fit[5];

assign int_ctrl_ready = 1'b1;
always @(posedge clk) begin
  if (reset) begin
    int_en <= 0;
  end else begin
    if (int_ctrl_ready && int_ctrl_valid) begin
      int_en <= int_ctrl_data;
    end
  end
end

reg [COUNT - 1:0]      reg_int_ready;
reg [1:0]              pcie_int_state;

assign int_ready = reg_int_ready;
assign int_stat_valid = 1'b1;
assign int_stat_data  = int_valid;

reg assert_halt;
wire int_new_avail = ~assert_halt && (int_active != 0) || assert_halt && (int_active & ~msi_ready_clean_msk != 0);

localparam PCIE_INT_IDLE          = 0;
localparam PCIE_INT_WAIT_USER_ACK = 1; // For legacy PCI interrupts only
localparam PCIE_INT_WAIT_REL_L    = 2; // for MSI interrupt covering multi-vector
localparam PCIE_INT_WAIT_REL_H    = 3; // for MSI interrupt

always @(posedge clk) begin
  if (reset) begin
    pcie_int_state   <= PCIE_INT_IDLE;
    reg_int_ready    <= 0;
    interrupt        <= 0;
    interrupt_assert <= 0;
    assert_halt      <= 0;
    interrupt_num    <= 0;
  end else begin
    if (int_stat_ready && int_stat_valid && (assert_halt || interrupt_assert)) begin
      assert_halt    <= 1'b0;
      reg_int_ready  <= int_valid & msi_ready_clean_msk;
    end else begin
      reg_int_ready  <= 0;
    end

    case (pcie_int_state)
      PCIE_INT_IDLE: begin
      if (int_new_avail && (~legacy_interrupt_disabled || interrupt_msi_enabled)) begin
        interrupt          <= 1'b1;

        if (interrupt_msi_enabled) begin
          interrupt_num      <= msi_num_gen;

          if (msi_no_fit) begin
            pcie_int_state   <= PCIE_INT_WAIT_REL_L;
            assert_halt      <= 1'b1;
          end else begin
            pcie_int_state   <= PCIE_INT_WAIT_REL_H;
          end
        end else begin
          // Legacy interrupt
          interrupt_num    <= 0;
          interrupt_assert <= 1'b1;
          pcie_int_state   <= PCIE_INT_WAIT_USER_ACK;
        end
      end
      end

      PCIE_INT_WAIT_USER_ACK: begin
        if (int_stat_ready && int_stat_valid && (assert_halt || interrupt_assert)) begin
          interrupt_assert <= 0;
          interrupt        <= 1'b1;
        end else begin
          if (interrupt_rdy) begin
            interrupt        <= 1'b0;
            if (~interrupt_assert) begin
              pcie_int_state <= PCIE_INT_IDLE;
            end
          end
        end
      end

      PCIE_INT_WAIT_REL_L, PCIE_INT_WAIT_REL_H: begin
        if (interrupt_rdy) begin
          interrupt                      <= 1'b0;
          if (pcie_int_state == PCIE_INT_WAIT_REL_H) begin
            reg_int_ready[interrupt_num] <= 1'b1;
          end
        end

        if (~interrupt) begin
          pcie_int_state  <= PCIE_INT_IDLE;
        end
      end

    endcase
  end
end


endmodule
