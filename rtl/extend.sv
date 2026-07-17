module extend #(
    parameter int XLEN = 32
) (
    input  logic [    31:0] instr,
    input  logic [     2:0] imm_src,
    output logic [XLEN-1:0] imm_ext
);

  always_comb begin
    case (imm_src)
      3'd0: imm_ext = {{20{instr[31]}}, instr[31:20]};  // I-type
      3'd1: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};  // S-type
      3'd2: imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};  // SB/B-type
      3'd3: imm_ext = {instr[31:12], 12'b0};  // U-type
      3'd4: imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};  // UJ/J-type
      default: imm_ext = 'x;
    endcase
  end

endmodule
