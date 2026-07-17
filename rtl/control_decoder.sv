module control_decoder
  import csr_pkg::*;
  import opcode_pkg::*;
(
    input  logic [ 6:0] op,
    input  logic [ 2:0] funct3,
    input  logic [11:0] funct12,
    output logic        reg_write,
    output logic [ 2:0] imm_src,
    output logic [ 1:0] alu_a_src,
    output logic        pc_target_src,
    output logic        alu_src,
    output logic        mem_write,
    output logic [ 1:0] result_src,
    output logic        branch,
    output logic        jump,
    output logic [ 1:0] alu_op,
    output logic        csr_access,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic        is_mret
);

  // imm_src encoding: 0=I, 1=S, 2=B, 3=U, 4=J
  localparam logic [2:0] ImmI = 3'd0;
  localparam logic [2:0] ImmS = 3'd1;
  localparam logic [2:0] ImmB = 3'd2;
  localparam logic [2:0] ImmU = 3'd3;
  localparam logic [2:0] ImmJ = 3'd4;

  localparam logic [1:0] SrcARs1 = 2'd0;
  localparam logic [1:0] SrcAPc = 2'd1;
  localparam logic [1:0] SrcAZero = 2'd2;

  // result_src: 0=alu, 1=mem read, 2=pc+4
  localparam logic [1:0] ResAlu = 2'd0;
  localparam logic [1:0] ResMem = 2'd1;
  localparam logic [1:0] ResPc4 = 2'd2;

  // alu_op
  localparam logic [1:0] AluOpAdd = 2'b00;  // address / pc math
  localparam logic [1:0] AluOpBranch = 2'b01;  // compare for branches
  localparam logic [1:0] AluOpFunct = 2'b10;  // decode from funct3/funct7

  always_comb begin
    reg_write     = 1'b0;
    imm_src       = ImmI;
    alu_a_src     = SrcARs1;
    pc_target_src = 1'b0;
    alu_src       = 1'b0;
    mem_write     = 1'b0;
    result_src    = ResAlu;
    branch        = 1'b0;
    jump          = 1'b0;
    alu_op        = AluOpAdd;
    csr_access    = 1'b0;
    is_ecall      = 1'b0;
    is_ebreak     = 1'b0;
    is_mret       = 1'b0;

    case (op)
      OpcodeOp: begin  // add, sub, and, or, xor, sll, srl, sra, slt, sltu
        reg_write = 1'b1;
        alu_src   = 1'b0;
        alu_op    = AluOpFunct;
      end

      OpcodeOpImm: begin  // addi, andi, ori, xori, slli, srli, srai, slti, sltiu
        reg_write = 1'b1;
        imm_src   = ImmI;
        alu_src   = 1'b1;
        alu_op    = AluOpFunct;
      end

      OpcodeLoad: begin  // lw
        reg_write  = 1'b1;
        imm_src    = ImmI;
        alu_src    = 1'b1;
        result_src = ResMem;
        alu_op     = AluOpAdd;
      end

      OpcodeStore: begin  // sw
        imm_src   = ImmS;
        alu_src   = 1'b1;
        mem_write = 1'b1;
        alu_op    = AluOpAdd;
      end

      OpcodeBranch: begin  // beq, bne, blt, bge, bltu, bgeu
        imm_src = ImmB;
        alu_src = 1'b0;
        branch  = 1'b1;
        alu_op  = AluOpBranch;
      end

      OpcodeJal: begin  // jal
        reg_write  = 1'b1;
        imm_src    = ImmJ;
        result_src = ResPc4;
        jump       = 1'b1;
      end

      OpcodeJalr: begin  // jalr
        reg_write     = 1'b1;
        imm_src       = ImmI;
        alu_src       = 1'b1;
        result_src    = ResPc4;
        jump          = 1'b1;
        alu_op        = AluOpAdd;  // alu computes rs1 + imm as the target
        pc_target_src = 1'b1;  // pc target comes from the alu, not pc + imm
      end

      OpcodeLui: begin  // lui
        reg_write = 1'b1;
        imm_src   = ImmU;
        alu_a_src = SrcAZero;
        alu_src   = 1'b1;
        alu_op    = AluOpAdd;
      end

      OpcodeAuipc: begin  // auipc
        reg_write = 1'b1;
        imm_src   = ImmU;
        alu_a_src = SrcAPc;
        alu_src   = 1'b1;
        alu_op    = AluOpAdd;
      end

      OpcodeSystem: begin
        if (funct3 == Funct3Priv) begin
          is_ecall  = (funct12 == Funct12Ecall);
          is_ebreak = (funct12 == Funct12Ebreak);
          is_mret   = (funct12 == Funct12Mret);
        end else begin
          reg_write  = 1'b1;
          csr_access = 1'b1;
        end
      end

      default: begin
        reg_write     = 1'b0;
        imm_src       = 3'bxxx;
        alu_a_src     = 2'bxx;
        pc_target_src = 1'bx;
        alu_src       = 1'bx;
        mem_write     = 1'b0;
        result_src    = 2'bxx;
        branch        = 1'b0;
        jump          = 1'b0;
        alu_op        = 2'bxx;
      end
    endcase
  end

endmodule
