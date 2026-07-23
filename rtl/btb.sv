module btb
  import bp_pkg::*;
#(
    parameter  int XLEN   = 32,
    localparam int TagLen = XLEN - 2 - BtbIdxLen
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // IF lookup
    input  logic [XLEN-1:0] lookup_pc,
    output logic            hit,
    output logic [XLEN-1:0] target,
    output logic            is_cond,

    // EX update
    input logic            update_valid,
    input logic [XLEN-1:0] update_pc,
    input logic [XLEN-1:0] update_target,
    input logic            update_is_cond
);

  logic              valid[BtbDepth];
  logic [TagLen-1:0] tag  [BtbDepth];
  logic [  XLEN-1:0] targ [BtbDepth];
  logic              cond [BtbDepth];

  assign hit = (valid[lookup_pc[2+:BtbIdxLen]] &&
                tag[lookup_pc[2+:BtbIdxLen]] == lookup_pc[BtbIdxLen+2+:TagLen]);

  assign target = targ[lookup_pc[2+:BtbIdxLen]];
  assign is_cond = cond[lookup_pc[2+:BtbIdxLen]];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < BtbDepth; i++) valid[i] <= 1'b0;
    end else if (core_en) begin
      if (update_valid) begin
        valid[update_pc[2+:BtbIdxLen]] <= 1'b1;
        tag[update_pc[2+:BtbIdxLen]]   <= update_pc[BtbIdxLen+2+:TagLen];
        targ[update_pc[2+:BtbIdxLen]]  <= update_target;
        cond[update_pc[2+:BtbIdxLen]]  <= update_is_cond;
      end
    end
  end

endmodule
