module mem_delay
  import cache_pkg::*;
#(
    parameter int XLEN = 32,
    parameter int DEPTH = 16384,
    parameter int Latency = 20,
    localparam int Lines = DEPTH / LineWords,
    localparam int LineIdxLen = $clog2(Lines),
    localparam int CntWidth = $clog2(Latency + 1)
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // Line
    input  logic                req_valid,
    input  logic                req_rw,
    input  logic [    XLEN-1:0] req_addr,
    input  logic [LineBits-1:0] req_wdata,
    output logic [LineBits-1:0] resp_rdata,
    output logic                resp_ready,

    // Boot
    input logic            boot_we,
    input logic [XLEN-1:0] boot_addr,
    input logic [XLEN-1:0] boot_wdata
);

  logic [LineIdxLen-1:0] line_idx;
  logic [LineIdxLen-1:0] boot_idx;
  logic [LineIdxLen-1:0] wr_idx;
  logic [ BlkOffLen-1:0] boot_word;

  logic [CntWidth-1:0] cnt;
  logic busy;
  logic done;

  logic                req_rw_q;
  logic [    XLEN-1:0] req_addr_q;
  logic [LineBits-1:0] req_wdata_q;

  localparam int Lanes = LineBits / 8;

  logic [LineBits-1:0] wr_data;
  logic [   Lanes-1:0] wr_lane;
  logic                wr_en;

  assign line_idx  = req_addr_q[IdxLsb+:LineIdxLen];
  assign boot_idx  = boot_addr[IdxLsb+:LineIdxLen];
  assign boot_word = boot_addr[2+:BlkOffLen];

  assign done = busy && (cnt >= CntWidth'(Latency - 1));

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      busy       <= 1'b0;
      cnt        <= '0;
      resp_ready <= 1'b0;
    end else if (core_en) begin
      resp_ready <= 1'b0;
      if (boot_we) begin
        busy <= 1'b0;
      end else if (!busy) begin
        if (req_valid && !resp_ready) begin
          busy        <= 1'b1;
          cnt         <= 1;
          req_rw_q    <= req_rw;
          req_addr_q  <= req_addr;
          req_wdata_q <= req_wdata;
        end
      end else if (done) begin
        busy       <= 1'b0;
        resp_ready <= 1'b1;
      end else begin
        cnt <= cnt + 1'b1;
      end
    end
  end

  // No read modify write
  assign wr_en   = boot_we || (done && req_rw_q);
  assign wr_idx  = boot_we ? boot_idx : line_idx;
  assign wr_data = boot_we ? {LineWords{boot_wdata}} : req_wdata_q;  // Boot word every slot

  // Strobe the boot word
  always_comb begin
    for (int b = 0; b < Lanes; b++) begin
      wr_lane[b] = !boot_we || (boot_word == BlkOffLen'(b / 4));
    end
  end

  bram_sdp #(
      .Width(LineBits),
      .Depth(Lines)
  ) u_line (
      .clk  (clk),
      .we   (core_en && wr_en),
      .wlane(wr_lane),
      .widx (wr_idx),
      .wdata(wr_data),
      .re   (core_en && done),
      .ridx (line_idx),
      .rdata(resp_rdata)
  );

endmodule
