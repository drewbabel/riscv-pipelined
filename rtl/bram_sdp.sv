module bram_sdp #(
    parameter int Width = 8,
    parameter int Depth = 256,
    parameter bit Block = 1'b1,  // 1 bram, 0 distributed
    localparam int AddrW = $clog2(Depth),
    localparam int Lanes = (Width + 7) / 8
) (
    input  logic             clk,
    input  logic             we,
    input  logic [Lanes-1:0] wlane,  // Lane strobes
    input  logic [AddrW-1:0] widx,
    input  logic [Width-1:0] wdata,
    input  logic             re,
    input  logic [AddrW-1:0] ridx,
    output logic [Width-1:0] rdata
);

// TB preload
`ifdef SIM_BACKDOOR
  logic             bd_we = 1'b0;
  logic [AddrW-1:0] bd_idx;
  logic [Width-1:0] bd_data;
`endif

  // Byte lanes dodge parity pins
  for (genvar b = 0; b < Lanes; b++) begin : g_lane
    localparam int Lo = 8 * b;
    localparam int W = (Width - Lo < 8) ? Width - Lo : 8;
    if (Block) begin : g_bram
      (* ram_style = "block" *) logic [W-1:0] bmem[Depth];
      // Zero init
      initial for (int i = 0; i < Depth; i++) bmem[i] = '0;
      always_ff @(posedge clk) begin
        if (we && wlane[b]) bmem[widx] <= wdata[Lo+:W];
        if (re) rdata[Lo+:W] <= bmem[ridx];
`ifdef SIM_BACKDOOR
        if (bd_we) bmem[bd_idx] <= bd_data[Lo+:W];
`endif
      end
    end else begin : g_dist
      (* ram_style = "distributed" *) logic [W-1:0] bmem[Depth];
      // Zero init
      initial for (int i = 0; i < Depth; i++) bmem[i] = '0;
      always_ff @(posedge clk) begin
        if (we && wlane[b]) bmem[widx] <= wdata[Lo+:W];
        if (re) rdata[Lo+:W] <= bmem[ridx];
`ifdef SIM_BACKDOOR
        if (bd_we) bmem[bd_idx] <= bd_data[Lo+:W];
`endif
      end
    end
  end

endmodule
