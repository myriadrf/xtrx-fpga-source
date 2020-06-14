module ul_qspi_mem #(
    parameter MEM_ADDR_BITS = 16
)(
    input         clk,
    input         reset,

    ///////////////////////////////
    // UL
    //
    ///// qspi excmd
    input         qspi_excmd_valid,
    input  [31:0] qspi_excmd_data,
    output        qspi_excmd_ready,

    ///// qspi cmd
    input         qspi_cmd_valid,
    input  [31:0] qspi_cmd_data,
    output        qspi_cmd_ready,

    ///// qspi debug Rd
    output        qspi_rd_valid,
    output [31:0] qspi_rd_data,
    input         qspi_rd_ready,

    ///// qspi status
    output        qspi_stat_valid,
    output [31:0] qspi_stat_data,
    input         qspi_stat_ready,

    //////////////////////////////
    // Buffer memory interface
    //
    output [MEM_ADDR_BITS - 1:2] mem_addr,
    output reg                   mem_valid,
    output                       mem_wr,
    output [31:0]                mem_out_data,
    input                        mem_ready,

    input [31:0]                 mem_in_data,
    input                        mem_in_valid,

    //////////////////////////////
    // QSPI if
    output reg [7:0] flash_cmd_data,
    output reg       flash_cmd_valid,
    input            flash_cmd_ready,
    output reg       flash_cmd_tlast,

    input  [7:0] flash_in_data,
    input        flash_in_valid,
    output       flash_in_ready,
    input        flash_in_tlast
);

// QSPI command
// [7:0] cmd | [7:0] size | [15:4] addr | memop | [1:0] ecmdsz | wnr
//
localparam UL_QSPI_WRNRD_OFF    = 0;
localparam UL_QSPI_EXCMDSZ_OFF  = 1;
localparam UL_QSPI_MEMVALID_OFF = 3;
localparam UL_QSPI_MEMADDR_OFF  = 4;
localparam UL_QSPI_SZ_OFF       = 16;
localparam UL_QSPI_CMD_OFF      = 24;

assign qspi_rd_valid = 1'b1;

// STAT register
wire qspi_stat_busy;

assign qspi_stat_valid = 1'b1;
assign qspi_stat_data = { 31'b0, qspi_stat_busy };

localparam ST_READY     = 0;
localparam ST_CMD       = 1;
localparam ST_CMDEX     = 2;
localparam ST_DOUT_ADDR = 3;
localparam ST_DOUT      = 4;
localparam ST_DIN       = 5;
localparam ST_DIN_MEMWR = 6;
localparam ST_FIN       = 7;

reg [2:0]                 state;

reg [7:0]                 byte_count;
reg                       zero_byte_count;

reg [MEM_ADDR_BITS - 1:2] mem_addr_op;
reg [31:0]                qspi_excmd_data_reg; // serialized in big endian format
reg [31:0]                in_qspi_rd;
reg [31:0]                mem_in_data_latched;
reg [1:0]                 in_qspi_byte;

reg [1:0]                 state_serialized;

reg                       wrnrd;

assign qspi_rd_data = in_qspi_rd;

assign qspi_excmd_ready = (state != ST_CMDEX && state != ST_CMD);

always @(posedge clk) begin
  if (reset) begin
    qspi_excmd_data_reg <= 0;
  end else begin
    if (qspi_excmd_valid && qspi_excmd_ready) begin
      qspi_excmd_data_reg <= qspi_excmd_data;
    end
  end
end


reg rem_none;
reg mem_oprd;

assign mem_addr = mem_addr_op;

always @(posedge clk) begin
  if (reset) begin
    mem_valid <= 1'b0;
  end else begin
    if (state == ST_READY && qspi_cmd_valid && qspi_cmd_ready) begin
        mem_addr_op <= { qspi_cmd_data[UL_QSPI_MEMADDR_OFF+11:UL_QSPI_MEMADDR_OFF], 2'b0 };
        byte_count  <= qspi_cmd_data[UL_QSPI_SZ_OFF+7:UL_QSPI_SZ_OFF];
        rem_none    <= 0;
    end else begin
      if (state == ST_DOUT_ADDR && (flash_cmd_ready || ~flash_cmd_valid) ||
            state == ST_DIN_MEMWR && mem_valid == 0) begin
        mem_valid   <= 1'b1;
        byte_count  <= byte_count - 4;

      end else if (mem_valid && mem_ready) begin
        mem_valid   <= 1'b0;
        mem_addr_op <= mem_addr_op + 1'b1;
        rem_none    <= (byte_count[7:2] == 0);
      end
    end
  end
end

reg  rd_last;
reg  data_out_valid;
wire data_last_processed = (state == ST_DOUT) && (flash_cmd_ready || ~flash_cmd_valid) && (state_serialized == 2'b11 || rem_none);


always @(posedge clk) begin
  if (reset) begin
    data_out_valid      <= 1'b0;
  end else if (mem_in_valid) begin
    mem_in_data_latched <= mem_in_data;
    data_out_valid      <= 1'b1;
  end else if (/*data_out_valid && data_last_processed*/ state != ST_DOUT) begin
    data_out_valid      <= 1'b0;
  end
end

assign mem_wr = ~wrnrd;
assign mem_out_data = in_qspi_rd;
assign flash_in_ready = (state == ST_DIN);

assign qspi_stat_busy = (state != ST_READY);

reg [7:0] cmd;

localparam QIO_QCFR_0   = 8'h0B;  //    3/4       10         1+              0
localparam QIO_QCFR_1   = 8'h6B;  //    3/4       10         1+              0
localparam QIO_QCFR_2   = 8'hEB;  //    3/4       10         1+              0
localparam QIO_QCFR4B_0 = 8'h0C;  //    4         10         1+              0
localparam QIO_QCFR4B_1 = 8'h6C;  //    4         10         1+              0
localparam QIO_QCFR4B_2 = 8'hEC;  //    4         10         1+              0
localparam QIO_QCPP_0   = 8'h02;  //    3/4       0          0               1-256
localparam QIO_QCPP_1   = 8'h32;  //    3/4       0          0               1-256
localparam QIO_QCPP_2   = 8'h12;  //    3/4       0          0               1-256

wire data_commands = (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR_0) ||
                     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR_1) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR_2) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR4B_0) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR4B_1) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCFR4B_2) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCPP_0) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCPP_1) ||
		     (qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF] == QIO_QCPP_2);

always @(posedge clk) begin
  if (reset) begin
    state <= ST_READY;

    flash_cmd_valid <= 1'b0;
    flash_cmd_tlast <= 1'b0;
  end else begin
    case (state)
    ST_READY: begin
      if (qspi_cmd_valid && qspi_cmd_ready) begin
       cmd             <= qspi_cmd_data[UL_QSPI_CMD_OFF+7:UL_QSPI_CMD_OFF];
       //byte_count      <= qspi_cmd_data[UL_QSPI_SZ_OFF+7:UL_QSPI_SZ_OFF];
       zero_byte_count <= (qspi_cmd_data[UL_QSPI_SZ_OFF+7:UL_QSPI_SZ_OFF] == 0) && ~data_commands;

       mem_oprd        <= qspi_cmd_data[UL_QSPI_MEMVALID_OFF];
       state_serialized<= qspi_cmd_data[UL_QSPI_EXCMDSZ_OFF+1:UL_QSPI_EXCMDSZ_OFF];
       wrnrd           <= qspi_cmd_data[UL_QSPI_WRNRD_OFF];
       in_qspi_byte    <= 0;
       state           <= ST_CMD;

       flash_cmd_tlast <= 1'b0;
       flash_cmd_valid <= 1'b1;
       flash_cmd_data  <= qspi_cmd_data[UL_QSPI_SZ_OFF+7:UL_QSPI_SZ_OFF];
      end
    end

    ST_CMD: begin
      if (flash_cmd_ready) begin
	flash_cmd_valid <= 1'b1;
	flash_cmd_data  <= cmd;
	if (state_serialized == 0 && zero_byte_count) begin
	    flash_cmd_tlast <= 1'b1;
	    state           <= ST_FIN;
	end else begin
	    flash_cmd_tlast <= 1'b0;

	    if (state_serialized != 0) begin
	      state           <= ST_CMDEX;
	    end else if (wrnrd) begin
	      state           <= ST_DOUT_ADDR;
	    end else begin
	      flash_cmd_tlast <= 1'b1;
	      state           <= ST_DIN;
	    end
	end
      end
    end

    ST_CMDEX: begin
      if (flash_cmd_ready) begin
        // previous transfer finished
        case (state_serialized)
          2'b00: flash_cmd_data <= qspi_excmd_data_reg[7:0];
          2'b01: flash_cmd_data <= qspi_excmd_data_reg[15:8];
          2'b10: flash_cmd_data <= qspi_excmd_data_reg[23:16];
          2'b11: flash_cmd_data <= qspi_excmd_data_reg[31:24];
        endcase

        if (state_serialized == 0) begin
          if (zero_byte_count) begin
            flash_cmd_tlast <= 1'b1;
            state           <= ST_FIN;
          end else if (wrnrd) begin
            state           <= ST_DOUT_ADDR;
          end else begin
            flash_cmd_tlast <= 1'b1;
            state           <= ST_DIN;
	  end
        end else begin
          state_serialized  <= state_serialized - 1'b1;
        end
      end
    end

    ST_DOUT_ADDR: begin
      if (flash_cmd_ready || ~flash_cmd_valid) begin
        state             <= ST_DOUT;
        flash_cmd_valid   <= 1'b0;
      end
    end

    ST_DOUT: begin
      if (flash_cmd_ready || ~flash_cmd_valid) begin

        if (data_out_valid) begin
          case (state_serialized)
            2'b00: flash_cmd_data <= mem_in_data_latched[7:0];
            2'b01: flash_cmd_data <= mem_in_data_latched[15:8];
            2'b10: flash_cmd_data <= mem_in_data_latched[23:16];
            2'b11: flash_cmd_data <= mem_in_data_latched[31:24];
          endcase

          if (rem_none && (byte_count[1:0] == state_serialized + 1'b1)) begin
            flash_cmd_tlast <= 1'b1;
            state           <= ST_FIN;
          end else if (state_serialized == 2'b11) begin
            state           <= ST_DOUT_ADDR;
          end

          state_serialized  <= state_serialized + 1'b1;

          flash_cmd_valid   <= 1'b1;
        end else begin
          flash_cmd_valid   <= 1'b0;
        end
      end
    end

    ST_DIN: begin
      if (flash_cmd_ready) begin
        flash_cmd_valid <= 1'b0;
      end
      if (flash_in_valid) begin
        case (state_serialized)
          2'b00: in_qspi_rd[7:0]   <= flash_in_data;
          2'b01: in_qspi_rd[15:8]  <= flash_in_data;
          2'b10: in_qspi_rd[23:16] <= flash_in_data;
          2'b11: in_qspi_rd[31:24] <= flash_in_data;
        endcase

        state_serialized  <= state_serialized + 1'b1;
        rd_last           <= flash_in_tlast;

        if (~mem_oprd && flash_in_tlast) begin
          state <= ST_READY;
        end else if (mem_oprd && (state_serialized == 2'b11 || flash_in_tlast)) begin
          state <= ST_DIN_MEMWR;
        end
      end
    end

    ST_DIN_MEMWR: begin
      if (mem_valid && mem_ready) begin
        if (rd_last) begin
	  state <= ST_READY;
        end else begin
          state <= ST_DIN;
        end
      end
    end

    ST_FIN: begin
      if (flash_cmd_ready) begin
        flash_cmd_valid   <= 1'b0;
        state <= ST_READY;
      end
    end

    endcase
  end
end


assign qspi_cmd_ready = (state == ST_READY);


endmodule
