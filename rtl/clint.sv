module clint
  import csr_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    input  logic            sel,
    input  logic [     3:0] wstrb,
    input  logic [XLEN-1:0] addr,
    input  logic [XLEN-1:0] wdata,
    output logic [XLEN-1:0] rdata,

    output logic timer_irq
);

  logic [63:0] mtime;
  logic [63:0] mtimecmp;

  localparam logic [15:0] MtimecmpLo = 16'h4000;
  localparam logic [15:0] MtimecmpHi = 16'h4004;
  localparam logic [15:0] MtimeLo = 16'hBFF8;
  localparam logic [15:0] MtimeHi = 16'hBFFC;

  wire [15:0] off = addr[15:0];

  assign timer_irq = mtime >= mtimecmp;

  always_comb begin
    rdata = '0;
    if (sel) begin
      case (off)
        MtimecmpLo: rdata = mtimecmp[31:0];
        MtimecmpHi: rdata = mtimecmp[63:32];
        MtimeLo:    rdata = mtime[31:0];
        MtimeHi:    rdata = mtime[63:32];
        default:    rdata = '0;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      mtime    <= '0;
      mtimecmp <= '1;  // never fire until software programs it
    end else if (core_en) begin
      mtime <= mtime + 1;
      if (sel && |wstrb) begin
        for (int b = 0; b < 4; b++) begin
          if (wstrb[b]) begin
            case (off)
              MtimecmpLo: mtimecmp[8*b+:8] <= wdata[8*b+:8];
              MtimecmpHi: mtimecmp[32+8*b+:8] <= wdata[8*b+:8];
              MtimeLo:    mtime[8*b+:8] <= wdata[8*b+:8];
              MtimeHi:    mtime[32+8*b+:8] <= wdata[8*b+:8];
              default:    ;
            endcase
          end
        end
      end
    end
  end

endmodule
