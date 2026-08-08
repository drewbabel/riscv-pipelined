module riscv_single
  import alu_pkg::*;
  import csr_pkg::*;
  import opcode_pkg::*;
#(
    parameter int XLEN = 32
) (
    input  logic            clk,
    input  logic            core_en,
    input  logic            cycle_en,
    input  logic            rst_n,
    input  logic [XLEN-1:0] instr,
    input  logic [XLEN-1:0] read_data,
    input  logic            timer_irq,
    output logic [XLEN-1:0] pc,
    output logic            mem_write,
    output logic [XLEN-1:0] alu_result,
    output logic [XLEN-1:0] write_data,
    output logic [     3:0] store_wstrb,
    output logic [XLEN-1:0] store_data
);

  logic [2:0] funct3;
  assign funct3 = instr[14:12];
  logic [11:0] funct12;
  assign funct12 = instr[31:20];
  logic [6:0] opcode;
  assign opcode = instr[6:0];

  logic mem_write_raw;
  logic reg_write;
  logic reg_write_gated;
  logic [2:0] imm_src;
  logic [1:0] alu_a_src;
  logic alu_src;
  logic [1:0] result_src;
  alu_pkg::alu_op_e alu_ctrl;
  logic pc_src;
  logic pc_target_src;
  logic zero;
  logic lt;
  logic ltu;
  logic [XLEN-1:0] load_data;
  logic [XLEN-1:0] rs1_data;
  logic [XLEN-1:0] imm_ext;
  logic [XLEN-1:0] csr_rdata;
  logic csr_access;
  logic is_ecall;
  logic is_ebreak;
  logic is_mret;
  logic exc_illegal;
  logic exc_instr_misaligned;
  logic exc_load_misaligned;
  logic exc_store_misaligned;
  logic [XLEN-1:0] pc_target;
  logic trap_taken;
  logic [XLEN-1:0] trap_vector;
  logic mret_taken;
  logic [XLEN-1:0] mepc_out;
  logic [7:0] ld_byte;
  logic [15:0] ld_half;

  assign csr_access = (opcode == OpcodeSystem) && (funct3 != Funct3Priv);
  assign is_ecall = (opcode == OpcodeSystem) && (funct3 == Funct3Priv) && (funct12 == Funct12Ecall);
  assign is_ebreak = (opcode == OpcodeSystem) &&
   (funct3 == Funct3Priv) &&
   (funct12 == Funct12Ebreak);
  assign is_mret = (opcode == OpcodeSystem) && (funct3 == Funct3Priv) && (funct12 == Funct12Mret);
  assign exc_illegal = !(
      (opcode == OpcodeOp) ||
      (opcode == OpcodeOpImm) ||
      (opcode == OpcodeLoad) ||
      (opcode == OpcodeStore) ||
      (opcode == OpcodeBranch) ||
      (opcode == OpcodeJal) ||
      (opcode == OpcodeJalr) ||
      (opcode == OpcodeLui) ||
      (opcode == OpcodeAuipc) ||
      (opcode == OpcodeMiscMem) ||
      (opcode == OpcodeSystem)
    );
  assign exc_instr_misaligned =
      (opcode == OpcodeBranch || opcode == OpcodeJal || opcode == OpcodeJalr) &&
      ((pc_src ? pc_target[1:0] : pc[1:0]) != 2'b00);
  assign exc_load_misaligned = (opcode == OpcodeLoad) && (
      (funct3 == 3'b001 || funct3 == 3'b101) ? alu_result[0] :
      (funct3 == 3'b010) ? |alu_result[1:0] :
      1'b0
    );
  assign exc_store_misaligned = (opcode == OpcodeStore) && (
      (funct3 == 3'b001) ? alu_result[0] :
      (funct3 == 3'b010) ? |alu_result[1:0] :
      1'b0
    );


  sc_control_unit control_unit_inst (
      .op           (instr[6:0]),
      .funct3       (funct3),
      .funct12      (instr[31:20]),
      .funct7b5     (instr[30]),
      .zero         (zero),
      .lt           (lt),
      .ltu          (ltu),
      .reg_write    (reg_write),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .pc_target_src(pc_target_src),
      .alu_src      (alu_src),
      .mem_write    (mem_write_raw),
      .result_src   (result_src),
      .pc_src       (pc_src),
      .alu_ctrl     (alu_ctrl)
  );

  extend #(
      .XLEN(XLEN)
  ) extend_inst (
      .imm_src(imm_src),
      .instr  (instr),
      .imm_ext(imm_ext)
  );

  sc_csr #(
      .XLEN(XLEN)
  ) csr_inst (
      .clk                 (clk),
      .core_en             (core_en),
      .cycle_en            (cycle_en),
      .rst_n               (rst_n),
      .csr_access          (csr_access),
      .csr_addr            (funct12),
      .funct3              (funct3),
      .rs1_data            (rs1_data),
      .zimm                (instr[19:15]),
      .pc                  (pc),
      .bad_addr            (exc_instr_misaligned ? pc_target : alu_result),
      .exc_illegal         (exc_illegal),
      .exc_ecall           (is_ecall),
      .exc_ebreak          (is_ebreak),
      .exc_instr_misaligned(exc_instr_misaligned),
      .exc_load_misaligned (exc_load_misaligned),
      .exc_store_misaligned(exc_store_misaligned),
      .is_mret             (is_mret),
      .timer_irq           (timer_irq),
      .csr_rdata           (csr_rdata),
      .trap_taken          (trap_taken),
      .trap_vector         (trap_vector),
      .mret_taken          (mret_taken),
      .mepc_out            (mepc_out)
  );

  sc_datapath #(
      .XLEN(XLEN)
  ) datapath_inst (
      .clk          (clk),
      .core_en      (core_en),
      .rst_n        (rst_n),
      .reg_write    (reg_write_gated),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .alu_src      (alu_src),
      .result_src   (result_src),
      .csr_access   (csr_access),
      .csr_rdata    (csr_rdata),
      .alu_ctrl     (alu_ctrl),
      .pc_src       (pc_src),
      .pc_target_src(pc_target_src),
      .trap_taken   (trap_taken),
      .trap_vector  (trap_vector),
      .mret_taken   (mret_taken),
      .mepc_out     (mepc_out),
      .instr        (instr),
      .read_data    (load_data),
      .pc           (pc),
      .alu_result   (alu_result),
      .write_data   (write_data),
      .rs1_data     (rs1_data),
      .zero         (zero),
      .lt           (lt),
      .ltu          (ltu)
  );

  assign reg_write_gated = reg_write && !trap_taken;
  assign mem_write = mem_write_raw && !trap_taken;

  always_comb begin
    ld_byte = read_data[{alu_result[1:0], 3'b000}+:8];
    ld_half = read_data[{alu_result[1], 4'b0000}+:16];
    case (funct3)
      3'b000:  load_data = {{24{ld_byte[7]}}, ld_byte};  // lb
      3'b100:  load_data = {24'b0, ld_byte};  // lbu
      3'b001:  load_data = {{16{ld_half[15]}}, ld_half};  // lh
      3'b101:  load_data = {16'b0, ld_half};  // lhu
      default: load_data = read_data;  // lw
    endcase
  end

  // Replicate rs2, strobe picks lane
  always_comb begin
    store_data  = write_data;
    store_wstrb = 4'h0;
    if (mem_write) begin
      case (funct3)
        3'b000: begin  // sb
          store_data  = {4{write_data[7:0]}};
          store_wstrb = 4'b0001 << alu_result[1:0];
        end
        3'b001: begin  // sh
          store_data  = {2{write_data[15:0]}};
          store_wstrb = 4'b0011 << alu_result[1:0];
        end
        3'b010: begin  // sw
          store_data  = write_data;
          store_wstrb = 4'b1111;
        end
        default: ;
      endcase
    end
  end

  assign pc_target = pc_target_src ? {alu_result[XLEN-1:1], 1'b0} : (pc + imm_ext);



endmodule
