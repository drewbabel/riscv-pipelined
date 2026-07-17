module dmem #(
    parameter int XLEN = 32,
    parameter int DEPTH = 64,
    localparam int AddrWidth = $clog2(DEPTH),
    localparam int Byte = 4
) (
    input  logic            clk,
    input  logic [Byte-1:0] wstrb,
    input  logic [XLEN-1:0] addr,
    input  logic [XLEN-1:0] wdata,
    output logic [XLEN-1:0] rdata
);

  logic [XLEN-1:0] mem[DEPTH];

  assign rdata = mem[addr[AddrWidth+1:2]];

  genvar i;

  generate
    for (i = 0; i < Byte; i++) begin : g_we
      always_ff @(posedge clk) begin
        if (wstrb[i]) mem[addr[AddrWidth+1:2]][8*i+:8] <= wdata[8*i+:8];
      end
    end
  endgenerate

endmodule
