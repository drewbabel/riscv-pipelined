module uart_ctrl #(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // Bus
    input  logic            sel,
    input  logic            req,
    input  logic [     3:0] wstrb,
    input  logic [XLEN-1:0] addr,
    input  logic [XLEN-1:0] wdata,
    output logic [XLEN-1:0] rdata,

    // Receiver
    input logic       rx_valid,
    input logic [7:0] rx_data,

    // Transmitter
    input  logic       tx_ready,
    output logic       tx_valid,
    output logic [7:0] tx_data,

    // Core
    output logic irq
);

  localparam logic [1:0] TxDataOff = 2'd0;
  localparam logic [1:0] StatusOff = 2'd1;
  localparam logic [1:0] RxDataOff = 2'd2;
  localparam logic [1:0] CtrlOff = 2'd3;

  logic [1:0] off;
  logic       wr_stb;
  logic       rd_stb;
  logic       rx_take;

  logic [7:0] rx_byte;
  logic       rx_full;
  logic       rx_overrun;
  logic       rx_ie;

  assign off      = addr[3:2];
  assign wr_stb   = core_en && sel && |wstrb;
  assign rd_stb   = core_en && sel && req && !(|wstrb);

  assign tx_valid = wr_stb && (off == TxDataOff);
  assign tx_data  = wdata[7:0];

  always_comb begin
    case (off)
      StatusOff: rdata = {29'b0, rx_overrun, rx_full, tx_ready};
      RxDataOff: rdata = {24'b0, rx_byte};
      CtrlOff:   rdata = {31'b0, rx_ie};
      default:   rdata = {31'b0, tx_ready};
    endcase
  end

  assign rx_take = rd_stb && (off == RxDataOff);

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      rx_byte    <= '0;
      rx_full    <= 1'b0;
      rx_overrun <= 1'b0;
      rx_ie      <= 1'b0;
    end else if (core_en) begin
      if (rx_valid && (!rx_full || rx_take)) rx_byte <= rx_data;

      if (rx_valid) rx_full <= 1'b1;
      else if (rx_take) rx_full <= 1'b0;

      if (rx_valid && rx_full && !rx_take) rx_overrun <= 1'b1;
      else if (rx_take) rx_overrun <= 1'b0;

      if (wr_stb && (off == CtrlOff)) rx_ie <= wdata[0];
    end
  end

  assign irq = rx_full && rx_ie;

endmodule
