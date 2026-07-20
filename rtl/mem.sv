module mem #(
    parameter int XLEN = 32,
    parameter int DEPTH = 8192,
    localparam int AddrWidth = $clog2(DEPTH)
) (
    input  logic            clk,
    input  logic            core_en,
    // Fetch read port
    input  logic [XLEN-1:0] iaddr,
    output logic [XLEN-1:0] instr,
    // Data port
    input  logic [     3:0] wstrb,
    input  logic [XLEN-1:0] daddr,
    input  logic [XLEN-1:0] wdata,
    output logic [XLEN-1:0] rdata
);

  // Byte-lane BRAMs
  genvar b;
  generate
    for (b = 0; b < 4; b++) begin : g_lane
      logic [7:0] bmem[DEPTH];
      // Fetch read
      always_ff @(posedge clk) instr[8*b+:8] <= bmem[iaddr[AddrWidth+1:2]];
      // Gated write
      always_ff @(posedge clk) begin
        if (core_en && wstrb[b]) bmem[daddr[AddrWidth+1:2]] <= wdata[8*b+:8];
        rdata[8*b+:8] <= bmem[daddr[AddrWidth+1:2]];
      end
    end
  endgenerate

endmodule
