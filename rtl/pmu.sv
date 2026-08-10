module pmu #(
    parameter int XLEN = 32,
    parameter int CLK_FREQ_HZ = 50_000_000
) (
    input  logic [XLEN-1:0] addr,
    output logic [XLEN-1:0] rdata,

    input logic [XLEN-1:0] ic_hits,
    input logic [XLEN-1:0] ic_misses,
    input logic [XLEN-1:0] dc_hits,
    input logic [XLEN-1:0] dc_misses
);

  localparam logic [XLEN-1:0] ClkHz = CLK_FREQ_HZ;

  always_comb begin
    case (addr[4:2])
      3'd0: rdata = ic_hits;
      3'd1: rdata = ic_misses;
      3'd2: rdata = dc_hits;
      3'd3: rdata = dc_misses;
      3'd4: rdata = ClkHz;
      default: rdata = '0;
    endcase
  end

endmodule
