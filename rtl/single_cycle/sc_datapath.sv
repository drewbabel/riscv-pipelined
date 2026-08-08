module sc_datapath
  import alu_pkg::*;
#(
    parameter int XLEN = 32
) (
    input  logic                        clk,
    input  logic                        core_en,
    input  logic                        rst_n,
    input  logic                        reg_write,
    input  logic             [     2:0] imm_src,
    input  logic             [     1:0] alu_a_src,
    input  logic                        alu_src,
    input  logic             [     1:0] result_src,
    input  logic                        csr_access,
    input  logic             [XLEN-1:0] csr_rdata,
    input  alu_pkg::alu_op_e            alu_ctrl,
    input  logic                        pc_src,
    input  logic                        pc_target_src,
    input  logic                        trap_taken,
    input  logic             [XLEN-1:0] trap_vector,
    input  logic                        mret_taken,
    input  logic             [XLEN-1:0] mepc_out,
    input  logic             [XLEN-1:0] instr,
    input  logic             [XLEN-1:0] read_data,
    output logic             [XLEN-1:0] pc,
    output logic             [XLEN-1:0] alu_result,
    output logic             [XLEN-1:0] write_data,
    output logic             [XLEN-1:0] rs1_data,
    output logic                        zero,
    output logic                        lt,
    output logic                        ltu
);

  logic [XLEN-1:0] pc_next;
  logic [XLEN-1:0] pc_plus4;
  logic [XLEN-1:0] pc_target;
  logic [XLEN-1:0] rs2_data;
  logic [XLEN-1:0] imm_ext;
  logic [XLEN-1:0] src_a;
  logic [XLEN-1:0] src_b;
  logic [XLEN-1:0] result;

  pc #(
      .XLEN(XLEN),
      .RESET_ADDR('h0000_0000)
  ) pc_inst (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .pc_next(pc_next),
      .pc_q(pc)
  );

  sc_regfile #(
      .XLEN(XLEN)
  ) regfile_inst (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .we(reg_write),
      .waddr(instr[11:7]),
      .wdata(result),
      .raddr1(instr[19:15]),
      .raddr2(instr[24:20]),
      .rdata1(rs1_data),
      .rdata2(rs2_data)
  );

  extend #(
      .XLEN(XLEN)
  ) extend_inst (
      .imm_src(imm_src),
      .instr  (instr),
      .imm_ext(imm_ext)
  );

  alu #(
      .XLEN(XLEN)
  ) alu_inst (
      .a(src_a),
      .b(src_b),
      .alu_op(alu_ctrl),
      .result(alu_result),
      .zero(zero),
      .lt(lt),
      .ltu(ltu)
  );

  assign pc_plus4   = pc + 4;
  assign write_data = rs2_data;

  // Muxes
  always_comb begin
    // src_a
    case (alu_a_src)
      2'd0: src_a = rs1_data;
      2'd1: src_a = pc;
      2'd2: src_a = '0;
      default: src_a = '0;
    endcase

    // src_b
    src_b = alu_src ? imm_ext : rs2_data;

    // result
    if (csr_access) begin
      result = csr_rdata;
    end else begin
      case (result_src)
        2'd0: result = alu_result;
        2'd1: result = read_data;
        2'd2: result = pc_plus4;
        default: result = '0;
      endcase
    end

    pc_target = (pc_target_src) ? {alu_result[XLEN-1:1], 1'b0} : pc + imm_ext;
    if (trap_taken) begin
      pc_next = trap_vector;
    end else if (mret_taken) begin
      pc_next = mepc_out;
    end else begin
      pc_next = (pc_src) ? pc_target : pc_plus4;
    end
  end


endmodule
