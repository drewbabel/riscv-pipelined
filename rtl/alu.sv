module alu
  import alu_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic [XLEN-1:0] a,
    input logic [XLEN-1:0] b,
    input alu_pkg::alu_op_e alu_op,
    output logic [XLEN-1:0] result,
    output logic zero,
    output logic lt,
    output logic ltu
);

  localparam int SHAMT = $clog2(XLEN);  // Shift-amount width

  logic [SHAMT-1:0] shamt;
  logic signed_lt;
  logic unsigned_lt;

  assign shamt = b[SHAMT-1:0];

  always_comb begin
    case (alu_op)
      ALU_ADD:  result = a + b;
      ALU_SUB:  result = a - b;
      ALU_SLL:  result = a << shamt;
      ALU_SLT:  result = ($signed(a) < $signed(b)) ? 1 : 0;
      ALU_SLTU: result = (a < b) ? 1 : 0;
      ALU_XOR:  result = a ^ b;
      ALU_SRL:  result = a >> shamt;
      ALU_SRA:  result = $signed(a) >>> shamt;
      ALU_OR:   result = a | b;
      ALU_AND:  result = a & b;
      default:  result = '0;
    endcase
  end

  assign zero = (result == '0);
  assign signed_lt = ($signed(a) < $signed(b));
  assign unsigned_lt = (a < b);
  assign lt = signed_lt;
  assign ltu = unsigned_lt;

endmodule
