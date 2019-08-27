module qspi_phy(
    input clk,
    input reset,

    // Flash interface
    input      [3:0]    di,
    output reg [3:0]    do,
    output reg [3:0]    dt,
    output reg          dncs, // Crystal select

    output               phy_dout_ready,
    input                phy_rst,
    input                phy_dout_drive,
    input [7:0]          phy_dout_data,
    input                phy_dout_valid,
    input                phy_dout_qio_mode, // How to serialize bits

    output reg [7:0]     phy_din_data,
    output reg           phy_din_valid
);

reg                      phy_active;
reg [2:0]                phy_bit;
reg                      phy_out_valid;


assign phy_dout_ready = phy_active && (phy_bit == 3'b110 || phy_dout_qio_mode && ~phy_bit[0] || phy_rst);
//assign phy_din_valid  = phy_active && (phy_bit == 3'b000 || phy_dout_qio_mode && ~phy_bit[0] && dt[0]);

wire [2:0] bptr = phy_bit + 1;  //FIXME !!
wire [2:0] lbit = 7 - bptr;

always @(posedge clk) begin
  if (reset) begin
    dncs <= 1;
    dt   <= 4'b1111;
    do   <= 4'b1111;

    phy_active    <= 0;
    phy_bit       <= 3'b111;
    phy_din_valid <= 1'b0;

  end else begin
    if (phy_active && ~phy_rst) begin
      if (phy_dout_qio_mode) begin
        phy_din_valid     <= (phy_bit[0] == 1'b1);
      end else begin
        phy_din_valid     <= (phy_bit == 3'b111);
      end
    end else begin
      phy_din_valid <= 1'b0;
    end

    if (phy_dout_valid) begin
      phy_active    <= 1'b1;
      dncs          <= 1'b0;

      phy_bit           <= phy_bit + 1'b1;

      if (phy_dout_qio_mode) begin
        // QIO MODE
        dt            <= {4{~phy_dout_drive}};

        if (phy_bit[0]) begin
            do                <= phy_dout_data[7:4];
            /////phy_din_data[3:0] <= di;
        end else begin
            do                <= phy_dout_data[3:0];
            /////phy_din_data[7:4] <= di;
        end
      end else begin
        // ESPI mode
        dt            <= 4'b0110;  // Only lane 0 and 3 drives
        do[3]         <= 1'b1;

        do[0]             <=   phy_dout_data[lbit];
        /////phy_din_data[7:0] <= { phy_din_data[6:0], di[1] };
      end

    end else begin
      phy_active    <= 1'b0;
      dncs          <= 1'b1;
      dt            <= 4'b1111;
      phy_bit       <= 3'b111;
    end

    if (phy_rst) begin
      phy_bit <= 3'b0;
    end
  end
end

always @(negedge clk) begin
  if (phy_dout_valid && phy_dout_qio_mode) begin
    if (~phy_bit[0]) begin
      phy_din_data[3:0] <= di;
    end else begin
      phy_din_data[7:4] <= di;
    end
  end else if (phy_dout_valid) begin
    phy_din_data[7:0] <= { phy_din_data[6:0], di[1] };
  end
end

endmodule

module qspi_flash #(
    parameter MODE_QIO = 0, // ESPI otherwise
    parameter ADDR4BYTES_SUPPORTED = 0,
    parameter ADDR4BYTES_DEFAULT = 0,
    parameter XIP_SUPPORTED = 0,
    parameter DUMMY_CYCLES_DEF = 9
)(
    input clk,
    input reset,

    // Flash interface
    input      [3:0] di,
    output     [3:0] do,
    output     [3:0] dt,
    output           dncs, // Crystal select

    // XIP enabled, can sendout ADDR + data
    output       flash_xip_enabled,

    // Logical interface
    // First byte of command is always number of bytes expected to be read out
    input  [7:0] flash_cmd_data,
    input        flash_cmd_valid,
    output       flash_cmd_ready,
    input        flash_cmd_tlast,

    output [7:0] flash_out_data,
    output       flash_out_valid,
    input        flash_out_ready,
    output       flash_out_tlast
);

// Max CLK for most QuadSPI flashes are 108Mhz -> io 54MB/s MAX
//
// This module automatically switches between 4-spi and 1-spi
// double spi isn't supported
//
// Also it's automatically adds wait cycles for specific commands
//

// QSPI flash command
////////////////////////////////////  A bytes  D clocks  RData bytes   WData bytes
localparam QIO_MIORDID  = 8'hAF;  //    0         0          1-3             0
localparam QIO_RDSFDP   = 8'h5A;  //    3         8          1+              0
localparam QIO_QCFR_0   = 8'h0B;  //    3/4       10         1+              0
localparam QIO_QCFR_1   = 8'h6B;  //    3/4       10         1+              0
localparam QIO_QCFR_2   = 8'hEB;  //    3/4       10         1+              0
localparam QIO_QCFR4B_0 = 8'h0C;  //    4         10         1+              0
localparam QIO_QCFR4B_1 = 8'h6C;  //    4         10         1+              0
localparam QIO_QCFR4B_2 = 8'hEC;  //    4         10         1+              0
localparam QIO_ROTP     = 8'h4B;  //    3/4       10         1-65            0

localparam QIO_WREN     = 8'h06;  //    0         0          0               0
localparam QIO_WRDI     = 8'h04;  //    0         0          0               0

// Program commands
localparam QIO_QCPP_0   = 8'h02;  //    3/4       0          0               1-256
localparam QIO_QCPP_1   = 8'h32;  //    3/4       0          0               1-256
localparam QIO_QCPP_2   = 8'h12;  //    3/4       0          0               1-256
localparam QIO_POTP     = 8'h22;  //    3/4       0          0               1-65

localparam QIO_SSE      = 8'h20;  //    3/4       0          0               0
localparam QIO_SE       = 8'hD8;  //    3/4       0          0               0
localparam QIO_BE       = 8'hC7;  //    0         0          0               0
localparam QIO_PER      = 8'h7A;  //    0         0          0               0
localparam QIO_PES      = 8'h75;  //    0         0          0               0

localparam QIO_RDSR     = 8'h05;  //    0         0          1+              0
localparam QIO_WRSR     = 8'h01;  //    0         0          0               1
localparam QIO_RDLR     = 8'hE8;  //    3/4       0          1+              0
localparam QIO_WRLR     = 8'hE5;  //    3/4       0          0               1
localparam QIO_RFSR     = 8'h70;  //    0         0          2               0
localparam QIO_CLFSR    = 8'h50;  //    0         0          0               2
localparam QIO_RDVCR    = 8'h85;  //    0         0          1+              0
localparam QIO_WRVCR    = 8'h81;  //    0         0          0               1
localparam QIO_RDECR    = 8'h65;  //    0         0          1+              0
localparam QIO_WRECR    = 8'h61;  //    0         0          0               1

localparam QIO_EN4BYTEA = 8'hB7;  //    0         0          0               0
localparam QIO_EX4BYTEA = 8'hE9;  //    0         0          0               0
localparam QIO_WREAR    = 8'hC5;  //    0         0          0               0
localparam QIO_RDREAR   = 8'hC8;  //    0         0          0               0

localparam QIO_RSTEN    = 8'h66;  //    0         0          0               0
localparam QIO_RST      = 8'h99;  //    0         0          0               0

// ESPI protocol all commands like classical SPI except special
// D0 data out; D1 data in; except QIO commands
//////////////////////////////////////////////
localparam ESPI_RDID_0  = 8'h9E;
localparam ESPI_RDID_1  = 8'h9F;

// QIO READ, only first 8b are 1bit
localparam ESPI_QIOFR   = QIO_QCFR_2;
localparam ESPI_QIOFR4B = QIO_QCFR4B_2;

// QIO PROGRAMM
localparam ESPI_QIEFP   = QIO_QCPP_2;



localparam FST_IDLE     = 0;
localparam FST_COMMAND  = 2;
localparam FST_FIN      = 3;

localparam FST_ADDRESS  = 4;
localparam FST_DUMMY_C  = 5;
localparam FST_DOUT     = 6;
localparam FST_DIN      = 7;
localparam FST_DIN_WAIT = 1;

// only QIO is supported for now
reg                      phy_dout_qio_mode;
reg                      phy_dout_valid;
reg  [7:0]               phy_dout;
reg                      phy_ddrive;
reg                      phy_rst;
wire                     phy_din_strobe;
wire [7:0]               phy_din;
wire                     phy_ready;


qspi_phy qspi_phy(
    .clk(clk),
    .reset(reset),

    // Flash interface
    .di(di),
    .do(do),
    .dt(dt),
    .dncs(dncs), // Crystal select

    .phy_dout_ready(phy_ready),
    .phy_rst(phy_rst),
    .phy_dout_drive(phy_ddrive),
    .phy_dout_data(phy_dout),
    .phy_dout_valid(phy_dout_valid),
    .phy_dout_qio_mode(phy_dout_qio_mode),

    .phy_din_data(phy_din),
    .phy_din_valid(phy_din_strobe)
);


wire                     flash_cfg_xip;
wire                     flash_cfg_4bytemode;
wire [3:0]               flash_cfg_dummy_cycles;

reg [2:0]                flash_state;
reg [1:0]                flash_state_aidx;

reg [7:0]                flash_outburst;

reg                      flash_exp_dummy;  // Number of dummy cycles for this transaction
                                           // before data phase
reg                      flash_qio_switch;
reg [3:0]                flash_dummy_counter;


wire cmd_addr_3or4 = (flash_cmd_data == QIO_QCFR_0 ||
                      flash_cmd_data == QIO_QCFR_1 ||
                      flash_cmd_data == QIO_QCFR_2 ||
                      flash_cmd_data == QIO_ROTP   ||
                      flash_cmd_data == QIO_QCPP_0 ||
                      flash_cmd_data == QIO_QCPP_1 ||
                      flash_cmd_data == QIO_QCPP_2 ||
                      flash_cmd_data == QIO_POTP   ||
                      flash_cmd_data == QIO_SSE    ||
                      flash_cmd_data == QIO_SE     ||
                      flash_cmd_data == QIO_RDLR   ||
                      flash_cmd_data == QIO_WRLR);

wire cmd_addr_4 = (flash_cmd_data == QIO_QCFR4B_0 ||
                   flash_cmd_data == QIO_QCFR4B_1 ||
                   flash_cmd_data == QIO_QCFR4B_2);

wire cmd_r_dummy = (flash_cmd_data == QIO_QCFR_0   ||
                    flash_cmd_data == QIO_QCFR_1   ||
                    flash_cmd_data == QIO_QCFR_2   ||
                    flash_cmd_data == QIO_QCFR4B_0 ||
                    flash_cmd_data == QIO_QCFR4B_1 ||
                    flash_cmd_data == QIO_QCFR4B_2 /*||
                    flash_cmd_data == QIO_ROTP */);

wire espi_to_qio_after_cmd = (flash_cmd_data == ESPI_QIOFR ||
                              flash_cmd_data == ESPI_QIOFR4B ||
                              flash_cmd_data == ESPI_QIEFP);

generate
if (ADDR4BYTES_SUPPORTED) begin
  reg flash_cfg_4bytemode_r;
  assign flash_cfg_4bytemode = flash_cfg_4bytemode_r;

  always @(posedge clk) begin
    if (reset) begin
      flash_cfg_4bytemode_r <= ADDR4BYTES_DEFAULT;
    end else begin
      if (flash_state == FST_IDLE && flash_cmd_valid && flash_cmd_ready) begin
        if (flash_cmd_data == QIO_EN4BYTEA)
          flash_cfg_4bytemode_r <= 1'b1;
        else if (flash_cmd_data == QIO_EX4BYTEA)
          flash_cfg_4bytemode_r <= 1'b0;
      end
    end
  end
end else begin
  assign flash_cfg_4bytemode = ADDR4BYTES_DEFAULT;
end
endgenerate

// Hardcoded for now
assign flash_cfg_dummy_cycles = DUMMY_CYCLES_DEF;

assign flash_out_data = phy_din;

//assign flash_cmd_ready = (flash_state == FST_IDLE) && phy_dout_valid == 0;
assign flash_out_valid = (flash_state == FST_DIN) && phy_din_strobe;
assign flash_out_tlast = (flash_outburst == 8'h01);

/*
reg flash_cmd_ready_r;
always @(posedge clk) begin
  if (reset) begin
    flash_cmd_ready_r <= 1'b0;
  end else begin
    case (flash_state)
    FST_IDLE:   flash_cmd_ready_r <= ~flash_cmd_valid;
    FST_ADDRESS:flash_cmd_ready_r <= ~phy_ready;
    FST_DOUT:   flash_cmd_ready_r <= ~phy_ready;
    default:    flash_cmd_ready_r <= 0;
    endcase
  end
end
assign flash_cmd_ready = flash_cmd_ready_r;
*/

assign flash_xip_enabled = 0;

reg redbackdata;

assign flash_cmd_ready = (flash_state == FST_IDLE || flash_state == FST_COMMAND) ? 1'b1 :
                         (flash_state == FST_ADDRESS || flash_state == FST_DOUT) ? phy_ready : 1'b0;

always @(posedge clk) begin
  if (reset) begin
    flash_state       <= FST_IDLE;
    phy_ddrive        <= 0;
    phy_rst           <= 0;
    phy_dout_valid    <= 0;
    phy_dout_qio_mode <= MODE_QIO;
  end else begin

    case (flash_state)
    FST_IDLE: begin
      if (flash_cmd_valid && flash_cmd_ready && ~flash_cmd_tlast) begin
        //if (~MODE_QIO) begin
          phy_dout_qio_mode <= MODE_QIO;
        //end
        flash_state         <= FST_COMMAND;
        flash_dummy_counter <= flash_cfg_dummy_cycles;
        flash_outburst      <= flash_cmd_data;
        redbackdata         <= (flash_cmd_data != 0);
      end
    end

    // In XIP mode 1st byte is ADDRESS
    FST_COMMAND: begin
      if (flash_cmd_valid  && flash_cmd_ready) begin
        phy_ddrive          <= 1;
        phy_dout            <= flash_cmd_data;
        phy_dout_valid      <= 1'b1;

        flash_exp_dummy     <= cmd_r_dummy;

        if (~MODE_QIO) begin
          flash_qio_switch    <= espi_to_qio_after_cmd;
        end

        if (flash_cmd_tlast) begin
          // No address no write data commands
          if (redbackdata) begin
            flash_state <= FST_DIN_WAIT;
          end else begin
            flash_state <= FST_FIN;
          end
        end else begin
          if (flash_xip_enabled) begin
            flash_state      <= FST_ADDRESS;
            flash_state_aidx <= (flash_cfg_4bytemode) ? 2'b10 : 2'b01;
          end else if (cmd_addr_3or4 && flash_cfg_4bytemode || cmd_addr_4) begin
            flash_state      <= FST_ADDRESS;
            flash_state_aidx <= 2'b11;
          end else if (cmd_addr_3or4 && ~flash_cfg_4bytemode) begin
            flash_state      <= FST_ADDRESS;
            flash_state_aidx <= 2'b10;
          end else begin
            flash_state      <= FST_DOUT;
          end
        end
      end
    end

    FST_FIN: begin
      if (phy_dout_valid && phy_ready) begin
        flash_state         <= FST_IDLE;
        phy_dout_valid      <= 1'b0;
      end

      if (~phy_dout_valid) begin
        flash_state <= FST_IDLE;
      end
    end

    FST_ADDRESS: begin
      if (phy_ready && flash_cmd_valid) begin
        if (~MODE_QIO) begin
          phy_dout_qio_mode <= flash_qio_switch;
        end
        if (flash_qio_switch) begin
          flash_dummy_counter <= flash_cfg_dummy_cycles + 2; //<<<< FIXME!!!!
        end
        phy_dout            <= flash_cmd_data;
        flash_state_aidx    <= flash_state_aidx - 1'b1;
        if (flash_state_aidx == 0) begin
          if (flash_exp_dummy) begin
            flash_state <= FST_DUMMY_C;
          end else if (~flash_cmd_tlast) begin
            flash_state <= FST_DOUT;
          end else if (redbackdata) begin
            flash_state <= FST_DIN_WAIT;
          end else begin
            flash_state <= FST_FIN;
          end
        end else if (flash_cmd_tlast) begin
          // Got less ADDRESSS bytes than expected

          phy_dout_valid <= 1'b0;
          flash_state    <= FST_IDLE; // FST_ABORTED
        end
      end else if (phy_ready) begin
      // couldn't provide data -- abort
      phy_dout_valid <= 1'b0;
      flash_state    <= FST_IDLE; // FST_ABORTED
      end
    end

    FST_DUMMY_C: begin
      if (phy_ready || phy_rst) begin
        phy_dout   <= 8'b1111_1111;
        phy_ddrive <= 0;
        phy_rst    <= 1;

        flash_dummy_counter <= flash_dummy_counter - 1;
        if (flash_dummy_counter == 0) begin
          phy_rst     <= 0;
          flash_state <= FST_DIN;
        end
      end
    end

    FST_DOUT: begin
      if (phy_ready && flash_cmd_valid) begin
        phy_dout            <= flash_cmd_data;
        if (flash_cmd_tlast) begin
          flash_state <= FST_FIN;
        end
      end else if (phy_ready) begin
        phy_dout_valid <= 1'b0;
        flash_state    <= FST_IDLE; // FST_ABORTED
      end
    end

    FST_DIN_WAIT: begin
      if (phy_ready) begin
        phy_dout       <= 8'b1111_1111;
        phy_ddrive     <= 0;
      end

      if (phy_din_strobe && flash_out_ready) begin
        flash_state     <= FST_DIN;
      end
    end

    FST_DIN: begin
      if (phy_ready) begin
        phy_dout       <= 8'b1111_1111;
        phy_ddrive     <= 0;
      end

      if (phy_din_strobe && flash_out_ready) begin
        flash_outburst <= flash_outburst - 1;
        if (flash_outburst == 8'h01) begin
          //flash_out_tlast <= 1'b1;
          phy_dout_valid  <= 0;
          flash_state     <= FST_FIN;
        end
      end else if (phy_din_strobe && ~flash_out_ready) begin
        phy_dout_valid <= 1'b0;
        flash_state    <= FST_IDLE; // FST_ABORTED
      end
    end
    endcase

  end
end


endmodule
