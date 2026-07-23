module gshare
  import bp_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // IF lookup
    input  logic [    XLEN-1:0] predict_pc,
    output logic                predict_taken,
    output logic [GhistLen-1:0] predict_index,

    // EX update
    input logic                update_valid,
    input logic                update_taken,
    input logic [GhistLen-1:0] update_index
);

  logic [GhistLen-1:0] ghr;
  logic [         1:0] pht [PhtDepth];

  // Weakly not taken cold state
  initial
    for (int i = 0; i < PhtDepth; i++) pht[i] = 2'b01;

  assign predict_index = ($bits(predict_index))'(predict_pc >> 2) ^ ghr;

  // 2bit saturating counter
  assign predict_taken = pht[predict_index][1];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ghr <= '0;
    end else if (core_en) begin
      if (update_valid) begin
        if (update_taken) begin
          if (pht[update_index] != 2'b11) pht[update_index] <= pht[update_index] + 1;
        end else begin
          if (pht[update_index] != 2'b00) pht[update_index] <= pht[update_index] - 1;
        end

        ghr <= {ghr[GhistLen-2:0], update_taken};
      end
    end
  end

endmodule
