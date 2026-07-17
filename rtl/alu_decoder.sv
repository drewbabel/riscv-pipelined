module alu_decoder
  import alu_pkg::*;
(
    input  logic             [1:0] alu_op,
    input  logic             [2:0] funct3,
    input  logic                   funct7b5,
    input  logic                   op5,
    output alu_pkg::alu_op_e       alu_ctrl
);

  localparam logic [1:0] AluOpAdd = 2'b00;
  localparam logic [1:0] AluOpBranch = 2'b01;
  localparam logic [1:0] AluOpFunct = 2'b10;

  logic sub_variant;
  assign sub_variant = funct7b5 & op5;

  always_comb begin
    case (alu_op)
      AluOpAdd:    alu_ctrl = ALU_ADD;
      AluOpBranch: alu_ctrl = ALU_SUB;

      AluOpFunct: begin
        case (funct3)
          3'b000:  alu_ctrl = alu_pkg::alu_op_e'(sub_variant ? ALU_SUB : ALU_ADD);
          3'b001:  alu_ctrl = ALU_SLL;
          3'b010:  alu_ctrl = ALU_SLT;
          3'b011:  alu_ctrl = ALU_SLTU;
          3'b100:  alu_ctrl = ALU_XOR;
          3'b101:  alu_ctrl = alu_pkg::alu_op_e'(funct7b5 ? ALU_SRA : ALU_SRL);
          3'b110:  alu_ctrl = ALU_OR;
          3'b111:  alu_ctrl = ALU_AND;
          default: alu_ctrl = alu_pkg::alu_op_e'(4'bxxxx);
        endcase
      end

      default: alu_ctrl = alu_pkg::alu_op_e'(4'bxxxx);
    endcase
  end

endmodule
