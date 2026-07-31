module pmu #(
    parameter int XLEN = 32
) (
    input  logic [XLEN-1:0] addr,
    output logic [XLEN-1:0] rdata,

    input logic [XLEN-1:0] ic_hits,
    input logic [XLEN-1:0] ic_misses,
    input logic [XLEN-1:0] dc_hits,
    input logic [XLEN-1:0] dc_misses
);

  always_comb begin
    case (addr[3:2])
      2'd0: rdata = ic_hits;
      2'd1: rdata = ic_misses;
      2'd2: rdata = dc_hits;
      default: rdata = dc_misses;
    endcase
  end

endmodule
