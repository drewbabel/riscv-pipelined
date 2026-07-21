module datapath
  import alu_pkg::*;
  import opcode_pkg::*;
#(
    parameter int XLEN = 32
) (
    input  logic            clk,
    input  logic            core_en,
    input  logic            rst_n,
    input  logic [XLEN-1:0] instr,
    input  logic [XLEN-1:0] read_data,
    input  logic            timer_irq,
    output logic [XLEN-1:0] pc,
    output logic            mem_write,
    output logic [XLEN-1:0] alu_result,
    output logic [XLEN-1:0] write_data,
    output logic [     3:0] store_wstrb,
    output logic [XLEN-1:0] store_data,
    output logic [XLEN-1:0] mem_addr
`ifdef RISCV_FORMAL
    ,
    output logic            dbg_valid,
    output logic [XLEN-1:0] dbg_insn,
    output logic [XLEN-1:0] dbg_pc_rdata,
    output logic [XLEN-1:0] dbg_pc_wdata,
    output logic [XLEN-1:0] dbg_rs1_rdata,
    output logic [XLEN-1:0] dbg_rs2_rdata,
    output logic [XLEN-1:0] dbg_rd_wdata,
    output logic            dbg_reg_write,
    output logic [XLEN-1:0] dbg_mem_addr,
    output logic [     3:0] dbg_mem_wmask,
    output logic [XLEN-1:0] dbg_mem_wdata,
    output logic [XLEN-1:0] dbg_mem_rdata,
    output logic            dbg_trap,
    output logic [XLEN-1:0] dbg_csr_wdata,
    output logic [XLEN-1:0] dbg_mscratch,
    output logic [XLEN-1:0] dbg_mstatus,
    output logic [XLEN-1:0] dbg_mtvec,
    output logic [XLEN-1:0] dbg_mepc,
    output logic [XLEN-1:0] dbg_mcause,
    output logic [XLEN-1:0] dbg_mtval,
    output logic [XLEN-1:0] dbg_mie,
    output logic [XLEN-1:0] dbg_mip,
    output logic [XLEN-1:0] dbg_mcycle,
    output logic [XLEN-1:0] dbg_minstret,
    output logic [XLEN-1:0] dbg_mcycleh,
    output logic [XLEN-1:0] dbg_minstreth
`endif
);

  logic             [XLEN-1:0] pc_next;
  logic             [XLEN-1:0] pc_plus4;
  logic             [XLEN-1:0] rs1_data;
  logic             [XLEN-1:0] rs2_data;
  logic             [XLEN-1:0] imm_ext;
  logic             [XLEN-1:0] src_a;
  logic             [XLEN-1:0] src_b;
  logic             [XLEN-1:0] forwarded_rs1;
  logic             [XLEN-1:0] forwarded_rs2;
  logic             [XLEN-1:0] result;
  logic             [XLEN-1:0] result_ex;
  logic             [XLEN-1:0] load_data;
  logic             [     7:0] ld_byte;
  logic             [    15:0] ld_half;

  logic                        reg_write;
  logic                        mem_write_dec;
  logic             [     2:0] imm_src;
  logic             [     1:0] alu_a_src;
  logic                        alu_src;
  logic             [     1:0] result_src;
  logic                        pc_target_src;
  alu_pkg::alu_op_e            alu_ctrl;
  logic                        zero;
  logic                        lt;
  logic                        ltu;
  logic                        branch;
  logic                        jump;

  // Pipeline registers

  logic             [XLEN-1:0] instr_id;
  logic             [XLEN-1:0] pc_id;
  logic             [XLEN-1:0] pc_plus4_id;

  logic             [XLEN-1:0] pc_ex;
  logic             [XLEN-1:0] pc_plus4_ex;
  logic             [     2:0] funct3_ex;
  logic             [XLEN-1:0] imm_ext_ex;
  logic             [     1:0] alu_a_src_ex;
  logic                        pc_target_src_ex;
  logic                        alu_src_ex;
  logic                        mem_write_ex;
  logic             [     1:0] result_src_ex;
  alu_pkg::alu_op_e            alu_ctrl_ex;
  logic             [XLEN-1:0] rs1_data_ex;
  logic             [XLEN-1:0] rs2_data_ex;
  logic             [     4:0] rs1_ex;
  logic             [     4:0] rs2_ex;
  logic             [     4:0] rd_ex;
  logic                        reg_write_ex;
  logic                        branch_ex;
  logic                        jump_ex;

  logic             [XLEN-1:0] alu_result_mem;
  logic             [XLEN-1:0] pc_plus4_mem;
  logic             [     1:0] result_src_mem;
  logic             [XLEN-1:0] write_data_mem;
  logic                        mem_write_mem;
  logic             [     2:0] funct3_mem;
  logic             [     4:0] rd_mem;
  logic                        reg_write_mem;

  logic             [     1:0] result_src_wb;
  logic             [XLEN-1:0] pc_plus4_wb;
  logic             [XLEN-1:0] alu_result_wb;
  logic             [     4:0] rd_wb;
  logic             [XLEN-1:0] load_data_wb;
  logic                        reg_write_wb;

  // Hazard detection
  logic                        stall;
  logic                        flush;
  logic             [     1:0] forward_a;
  logic             [     1:0] forward_b;

  // Branch resolution
  logic                        branch_taken_ex;
  logic                        pc_src_ex;
  logic             [XLEN-1:0] pc_target_ex;

  // CSR trap
  logic                        csr_access;
  logic                        is_ecall;
  logic                        is_ebreak;
  logic                        is_mret;
  logic                        exc_illegal;
  logic             [XLEN-1:0] instr_ex;
  logic                        csr_access_ex;
  logic                        is_ecall_ex;
  logic                        is_ebreak_ex;
  logic                        is_mret_ex;
  logic                        exc_illegal_ex;
  logic                        valid_id;
  logic                        valid_ex;
  logic                        valid_mem;
  logic                        valid_wb;
  logic                        commit_valid;
  logic                        exc_instr_misaligned;
  logic                        exc_load_misaligned;
  logic                        exc_store_misaligned;
  logic                        mem_misaligned;
  logic             [XLEN-1:0] csr_rdata;
  logic                        trap_taken;
  logic             [XLEN-1:0] trap_vector;
  logic                        mret_taken;
  logic             [XLEN-1:0] mepc_out;
  logic             [XLEN-1:0] bad_addr;

  pc #(
      .XLEN(XLEN),
      .RESET_ADDR('h0000_0000)
  ) pc_inst (
      .clk(clk),
      .core_en(core_en && (!stall || flush)),
      .rst_n(rst_n),
      .pc_next(pc_next),
      .pc_q(pc)
  );

  // IF/ID
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      instr_id    <= '0;
      pc_id       <= '0;
      pc_plus4_id <= '0;
    end else if (core_en && flush) begin
      instr_id    <= 32'h0000_0013;  // NOP
      pc_id       <= '0;
      pc_plus4_id <= '0;
    end else if (core_en && !stall) begin
      instr_id    <= instr;
      pc_id       <= pc;
      pc_plus4_id <= pc_plus4;
    end
  end

  control_unit control_unit_inst (
      .op           (instr_id[6:0]),
      .funct3       (instr_id[14:12]),
      .funct12      (instr_id[31:20]),
      .funct7b5     (instr_id[30]),
      .reg_write    (reg_write),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .pc_target_src(pc_target_src),
      .alu_src      (alu_src),
      .mem_write    (mem_write_dec),
      .result_src   (result_src),
      .alu_ctrl     (alu_ctrl),
      .branch       (branch),
      .jump         (jump),
      .csr_access   (csr_access),
      .is_ecall     (is_ecall),
      .is_ebreak    (is_ebreak),
      .is_mret      (is_mret)
  );

  assign exc_illegal = !((instr_id[6:0] == OpcodeOp) || (instr_id[6:0] == OpcodeOpImm) ||
      (instr_id[6:0] == OpcodeLoad) || (instr_id[6:0] == OpcodeStore) ||
      (instr_id[6:0] == OpcodeBranch) || (instr_id[6:0] == OpcodeJal) ||
      (instr_id[6:0] == OpcodeJalr) || (instr_id[6:0] == OpcodeLui) ||
      (instr_id[6:0] == OpcodeAuipc) || (instr_id[6:0] == OpcodeMiscMem) ||
      (instr_id[6:0] == OpcodeSystem));

  regfile #(
      .XLEN(XLEN)
  ) regfile_inst (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .we(reg_write_wb),
      .waddr(rd_wb),
      .wdata(result),
      .raddr1(instr_id[19:15]),
      .raddr2(instr_id[24:20]),
      .rdata1(rs1_data),
      .rdata2(rs2_data)
  );

  extend #(
      .XLEN(XLEN)
  ) extend_inst (
      .imm_src(imm_src),
      .instr  (instr_id),
      .imm_ext(imm_ext)
  );

  // ID/EX
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      reg_write_ex <= 1'b0;
      mem_write_ex <= 1'b0;
    end else if (core_en) begin
      pc_ex            <= pc_id;
      pc_plus4_ex      <= pc_plus4_id;
      funct3_ex        <= instr_id[14:12];
      imm_ext_ex       <= imm_ext;
      alu_a_src_ex     <= alu_a_src;
      pc_target_src_ex <= pc_target_src;
      alu_src_ex       <= alu_src;
      result_src_ex    <= (stall || flush) ? 2'd0 : result_src;
      alu_ctrl_ex      <= alu_ctrl;
      rs1_data_ex      <= rs1_data;
      rs2_data_ex      <= rs2_data;
      reg_write_ex     <= (reg_write && !stall && !flush);
      mem_write_ex     <= (mem_write_dec && !stall && !flush);
      rd_ex            <= (stall || flush) ? 5'd0 : instr_id[11:7];
      rs1_ex           <= instr_id[19:15];
      rs2_ex           <= instr_id[24:20];
      branch_ex        <= (branch && !stall && !flush);
      jump_ex          <= (jump && !stall && !flush);
      instr_ex         <= instr_id;
      csr_access_ex    <= (csr_access && !stall && !flush);
      is_ecall_ex      <= (is_ecall && !stall && !flush);
      is_ebreak_ex     <= (is_ebreak && !stall && !flush);
      is_mret_ex       <= (is_mret && !stall && !flush);
      exc_illegal_ex   <= (exc_illegal && !stall && !flush);
    end
  end

  // Commit valid
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      valid_id  <= 1'b0;
      valid_ex  <= 1'b0;
      valid_mem <= 1'b0;
      valid_wb  <= 1'b0;
    end else if (core_en) begin
      if (flush) valid_id <= 1'b0;
      else if (!stall) valid_id <= 1'b1;
      valid_ex  <= valid_id && !stall && !flush;
      valid_mem <= valid_ex;
      valid_wb  <= valid_mem;
    end
  end

  assign commit_valid = valid_ex;

  hazard_unit #(
      .XLEN(XLEN)
  ) hazard_unit_inst (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .rs1_id(instr_id[19:15]),
      .rs2_id(instr_id[24:20]),
      .rs1_ex(rs1_ex),
      .rs2_ex(rs2_ex),
      .rd_id(instr_id[11:7]),
      .rd_ex(rd_ex),
      .rd_mem(rd_mem),
      .rd_wb(rd_wb),
      .reg_write_mem(reg_write_mem),
      .reg_write_wb(reg_write_wb),
      .mem_write_ex(mem_write_ex),
      .result_src_ex(result_src_ex),
      .result_src_mem(result_src_mem),
      .result_src_wb(result_src_wb),
      .stall(stall),
      .forward_a(forward_a),
      .forward_b(forward_b)
  );

  always_comb begin
    case (forward_a)
      2'b01:   forwarded_rs1 = alu_result_mem;
      2'b10:   forwarded_rs1 = result;
      default: forwarded_rs1 = rs1_data_ex;
    endcase

    case (forward_b)
      2'b01:   forwarded_rs2 = alu_result_mem;
      2'b10:   forwarded_rs2 = result;
      default: forwarded_rs2 = rs2_data_ex;
    endcase

    case (alu_a_src_ex)
      2'd0:    src_a = forwarded_rs1;
      2'd1:    src_a = pc_ex;
      2'd2:    src_a = '0;
      default: src_a = '0;
    endcase

    src_b = alu_src_ex ? imm_ext_ex : forwarded_rs2;
  end

  alu #(
      .XLEN(XLEN)
  ) alu_inst (
      .a(src_a),
      .b(src_b),
      .alu_op(alu_ctrl_ex),
      .result(alu_result),
      .zero(zero),
      .lt(lt),
      .ltu(ltu)
  );

  // Branch resolution
  always_comb begin
    case (funct3_ex)
      3'b000:  branch_taken_ex = zero;  // beq
      3'b001:  branch_taken_ex = !zero;  // bne
      3'b100:  branch_taken_ex = lt;  // blt
      3'b101:  branch_taken_ex = !lt;  // bge
      3'b110:  branch_taken_ex = ltu;  // bltu
      3'b111:  branch_taken_ex = !ltu;  // bgeu
      default: branch_taken_ex = 1'b0;
    endcase
  end

  assign pc_src_ex    = valid_ex && ((branch_ex & branch_taken_ex) | jump_ex);
  assign pc_target_ex = pc_target_src_ex ? {alu_result[XLEN-1:1], 1'b0} : (pc_ex + imm_ext_ex);

  // EX exceptions
  assign exc_instr_misaligned = commit_valid && (branch_ex || jump_ex) && pc_src_ex &&
      (pc_target_ex[1:0] != 2'b00);

  // Alignment by width
  always_comb begin
    case (funct3_ex)
      3'b001, 3'b101: mem_misaligned = alu_result[0];  // halfword
      3'b010:         mem_misaligned = |alu_result[1:0];  // word
      default:        mem_misaligned = 1'b0;
    endcase
  end

  assign exc_load_misaligned  = commit_valid && (result_src_ex == 2'd1) && mem_misaligned;
  assign exc_store_misaligned = commit_valid && mem_write_ex && mem_misaligned;
  assign bad_addr = exc_instr_misaligned ? pc_target_ex : alu_result;

  csr #(
      .XLEN(XLEN)
  ) csr_inst (
      .clk                 (clk),
      .core_en             (core_en && commit_valid),
      .cycle_en            (core_en),
      .rst_n               (rst_n),
      .csr_access          (csr_access_ex && commit_valid),
      .csr_addr            (instr_ex[31:20]),
      .funct3              (funct3_ex),
      .rs1_data            (forwarded_rs1),
      .zimm                (instr_ex[19:15]),
      .pc                  (pc_ex),
      .bad_addr            (bad_addr),
      .exc_illegal         (exc_illegal_ex && commit_valid),
      .exc_ecall           (is_ecall_ex && commit_valid),
      .exc_ebreak          (is_ebreak_ex && commit_valid),
      .exc_instr_misaligned(exc_instr_misaligned),
      .exc_load_misaligned (exc_load_misaligned),
      .exc_store_misaligned(exc_store_misaligned),
      .is_mret             (is_mret_ex && commit_valid),
      .timer_irq           (timer_irq && commit_valid),
      .csr_rdata           (csr_rdata),
      .trap_taken          (trap_taken),
      .trap_vector         (trap_vector),
      .mret_taken          (mret_taken),
      .mepc_out            (mepc_out)
`ifdef RISCV_FORMAL
      ,
      .dbg_csr_wdata       (dbg_csr_wdata),
      .dbg_mscratch        (dbg_mscratch),
      .dbg_mstatus         (dbg_mstatus),
      .dbg_mtvec           (dbg_mtvec),
      .dbg_mepc            (dbg_mepc),
      .dbg_mcause          (dbg_mcause),
      .dbg_mtval           (dbg_mtval),
      .dbg_mie             (dbg_mie),
      .dbg_mip             (dbg_mip),
      .dbg_mcycle          (dbg_mcycle),
      .dbg_minstret        (dbg_minstret),
      .dbg_mcycleh         (dbg_mcycleh),
      .dbg_minstreth       (dbg_minstreth)
`endif
  );

  // CSR read to writeback
  assign result_ex = csr_access_ex ? csr_rdata : alu_result;

  assign flush = pc_src_ex | trap_taken | mret_taken;

  // EX/MEM
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      reg_write_mem <= 1'b0;
      mem_write_mem <= 1'b0;
    end else if (core_en) begin
      alu_result_mem <= result_ex;
      pc_plus4_mem   <= pc_plus4_ex;
      write_data_mem <= forwarded_rs2;
      mem_write_mem  <= mem_write_ex && !trap_taken;
      funct3_mem     <= funct3_ex;
      reg_write_mem  <= reg_write_ex && !trap_taken;
      result_src_mem <= result_src_ex;
      rd_mem         <= rd_ex;
    end
  end

  assign write_data = write_data_mem;
  assign mem_write  = mem_write_mem;
  assign mem_addr   = alu_result_mem;

  // Memory access
  always_comb begin
    // Load data
    ld_byte = read_data[{alu_result_mem[1:0], 3'b000}+:8];
    ld_half = read_data[{alu_result_mem[1], 4'b0000}+:16];
    case (funct3_mem)
      3'b000:  load_data = {{24{ld_byte[7]}}, ld_byte};  // lb
      3'b100:  load_data = {24'b0, ld_byte};  // lbu
      3'b001:  load_data = {{16{ld_half[15]}}, ld_half};  // lh
      3'b101:  load_data = {16'b0, ld_half};  // lhu
      default: load_data = read_data;  // lw
    endcase

    // Store data
    store_data  = write_data_mem;
    store_wstrb = 4'h0;
    if (mem_write_mem) begin
      case (funct3_mem)
        3'b000: begin  // sb
          store_data  = {4{write_data_mem[7:0]}};
          store_wstrb = 4'b0001 << alu_result_mem[1:0];
        end
        3'b001: begin  // sh
          store_data  = {2{write_data_mem[15:0]}};
          store_wstrb = 4'b0011 << alu_result_mem[1:0];
        end
        3'b010: begin  // sw
          store_data  = write_data_mem;
          store_wstrb = 4'b1111;
        end
        default: ;
      endcase
    end
  end

  assign pc_plus4 = pc + 4;

  // MEM/WB
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      reg_write_wb <= 1'b0;
    end else if (core_en) begin
      result_src_wb <= result_src_mem;
      alu_result_wb <= alu_result_mem;
      pc_plus4_wb   <= pc_plus4_mem;
      reg_write_wb  <= reg_write_mem;
      load_data_wb  <= load_data;
      rd_wb         <= rd_mem;
    end
  end

  // Writeback
  always_comb begin
    case (result_src_wb)
      2'd0:    result = alu_result_wb;
      2'd1:    result = load_data_wb;
      2'd2:    result = pc_plus4_wb;
      default: result = '0;
    endcase
  end

  always_comb begin
    if (trap_taken) pc_next = trap_vector;
    else if (mret_taken) pc_next = mepc_out;
    else if (pc_src_ex) pc_next = pc_target_ex;
    else pc_next = pc_plus4;
  end

`ifdef RISCV_FORMAL
  // RVFI shadow pipeline
  logic [XLEN-1:0] rvfi_insn_ex, rvfi_insn_mem, rvfi_insn_wb;
  logic [XLEN-1:0] rvfi_pc_mem, rvfi_pc_wb;
  logic [XLEN-1:0] rvfi_pcw_mem, rvfi_pcw_wb;
  logic [XLEN-1:0] rvfi_rs1d_mem, rvfi_rs1d_wb;
  logic [XLEN-1:0] rvfi_rs2d_mem, rvfi_rs2d_wb;
  logic [XLEN-1:0] rvfi_memrd_wb;
  logic [     3:0] rvfi_wstrb_wb;
  logic [XLEN-1:0] rvfi_wdata_wb;
  logic            rvfi_trap_mem, rvfi_trap_wb;

  always_ff @(posedge clk) begin
    rvfi_insn_ex  <= instr_id;
    rvfi_insn_mem <= rvfi_insn_ex;
    rvfi_insn_wb  <= rvfi_insn_mem;

    rvfi_pc_mem   <= pc_ex;
    rvfi_pc_wb    <= rvfi_pc_mem;

    if (trap_taken) rvfi_pcw_mem <= trap_vector;
    else if (mret_taken) rvfi_pcw_mem <= mepc_out;
    else if (pc_src_ex) rvfi_pcw_mem <= pc_target_ex;
    else rvfi_pcw_mem <= pc_ex + 4;
    rvfi_pcw_wb <= rvfi_pcw_mem;

    rvfi_rs1d_mem <= forwarded_rs1;
    rvfi_rs1d_wb  <= rvfi_rs1d_mem;
    rvfi_rs2d_mem <= forwarded_rs2;
    rvfi_rs2d_wb  <= rvfi_rs2d_mem;

    rvfi_memrd_wb <= read_data;
    rvfi_wstrb_wb <= store_wstrb;
    rvfi_wdata_wb <= store_data;

    rvfi_trap_mem <= trap_taken;
    rvfi_trap_wb  <= rvfi_trap_mem;
  end

  assign dbg_valid     = valid_wb;
  assign dbg_insn      = rvfi_insn_wb;
  assign dbg_pc_rdata  = rvfi_pc_wb;
  assign dbg_pc_wdata  = rvfi_pcw_wb;
  assign dbg_rs1_rdata = rvfi_rs1d_wb;
  assign dbg_rs2_rdata = rvfi_rs2d_wb;
  assign dbg_rd_wdata  = result;
  assign dbg_reg_write = reg_write_wb;
  assign dbg_mem_addr  = alu_result_wb;
  assign dbg_mem_wmask = rvfi_wstrb_wb;
  assign dbg_mem_wdata = rvfi_wdata_wb;
  assign dbg_mem_rdata = rvfi_memrd_wb;
  assign dbg_trap      = rvfi_trap_wb;
`endif

endmodule
