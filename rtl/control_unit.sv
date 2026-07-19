module control_unit
  import alu_pkg::*;
  import csr_pkg::*;
(
    input  logic             [ 6:0] op,
    input  logic             [ 2:0] funct3,
    input  logic             [11:0] funct12,
    input  logic                    funct7b5,
    input  logic                    zero,
    input  logic                    lt,
    input  logic                    ltu,
    output logic                    reg_write,
    output logic             [ 2:0] imm_src,
    output logic             [ 1:0] alu_a_src,
    output logic                    pc_target_src,
    output logic                    alu_src,
    output logic                    mem_write,
    output logic             [ 1:0] result_src,
    output logic                    pc_src,
    output alu_pkg::alu_op_e        alu_ctrl
);

  logic [1:0] alu_op;
  logic branch;
  logic jump;
  logic csr_access;
  logic is_ecall;
  logic is_ebreak;
  logic is_mret;

  control_decoder u_decoder (
      .op           (op),
      .funct3       (funct3),
      .funct12      (funct12),
      .reg_write    (reg_write),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .pc_target_src(pc_target_src),
      .alu_src      (alu_src),
      .mem_write    (mem_write),
      .result_src   (result_src),
      .branch       (branch),
      .jump         (jump),
      .alu_op       (alu_op),
      .csr_access   (csr_access),
      .is_ecall     (is_ecall),
      .is_ebreak    (is_ebreak),
      .is_mret      (is_mret)
  );

  alu_decoder u_alu_decoder (
      .alu_op  (alu_op),
      .funct3  (funct3),
      .funct7b5(funct7b5),
      .op5     (op[5]),
      .alu_ctrl(alu_ctrl)
  );

  logic branch_taken;

  always_comb begin
    case (funct3)
      3'b000:  branch_taken = zero;  // beq
      3'b001:  branch_taken = !zero;  // bne
      3'b100:  branch_taken = lt;  // blt
      3'b101:  branch_taken = !lt;  // bge
      3'b110:  branch_taken = ltu;  // bltu
      3'b111:  branch_taken = !ltu;  // bgeu
      default: branch_taken = 1'b0;
    endcase
  end

  assign pc_src = (branch & branch_taken) | jump;

endmodule
