module datapath
  import alu_pkg::*;
#(
    parameter int XLEN = 32
) (
    input  logic            clk,
    input  logic            core_en,
    input  logic            rst_n,
    input  logic [XLEN-1:0] instr,
    input  logic [XLEN-1:0] read_data,
    output logic [XLEN-1:0] pc,
    output logic            mem_write,
    output logic [XLEN-1:0] alu_result,
    output logic [XLEN-1:0] write_data,
    output logic [     3:0] store_wstrb,
    output logic [XLEN-1:0] store_data,
    output logic [XLEN-1:0] mem_addr
`ifdef RISCV_FORMAL
    ,
    output logic [XLEN-1:0] dbg_rs1_data,
    output logic [XLEN-1:0] dbg_rd_wdata
`endif
);

  logic [XLEN-1:0] pc_next;
  logic [XLEN-1:0] pc_plus4;
  logic [XLEN-1:0] pc_target;
  logic [XLEN-1:0] rs1_data;
  logic [XLEN-1:0] rs2_data;
  logic [XLEN-1:0] imm_ext;
  logic [XLEN-1:0] src_a;
  logic [XLEN-1:0] src_b;
  logic [XLEN-1:0] result;
  logic [XLEN-1:0] load_data;
  logic [     7:0] ld_byte;
  logic [    15:0] ld_half;

  logic            reg_write;
  logic            mem_write_dec;
  logic [     2:0] imm_src;
  logic [     1:0] alu_a_src;
  logic            alu_src;
  logic [     1:0] result_src;
  logic            pc_src;
  logic            pc_target_src;
  alu_pkg::alu_op_e alu_ctrl;
  logic            zero;
  logic            lt;
  logic            ltu;

  // Pipeline registers

  logic [XLEN-1:0] instr_id;
  logic [XLEN-1:0] pc_id;
  logic [XLEN-1:0] pc_plus4_id;

  logic [XLEN-1:0] pc_ex;
  logic [XLEN-1:0] pc_plus4_ex;
  logic [2:0] funct3_ex;
  logic [XLEN-1:0] imm_ext_ex;
  logic [1:0] alu_a_src_ex;
  logic pc_target_src_ex;
  logic alu_src_ex;
  logic mem_write_ex;
  logic [1:0] result_src_ex;
  alu_pkg::alu_op_e alu_ctrl_ex;
  logic [XLEN-1:0] rs1_data_ex;
  logic [XLEN-1:0] rs2_data_ex;
  logic [4:0] rd_ex;
  logic reg_write_ex;

  logic [XLEN-1:0] alu_result_mem;
  logic [XLEN-1:0] pc_plus4_mem;
  logic [1:0] result_src_mem;
  logic [XLEN-1:0] write_data_mem;
  logic mem_write_mem;
  logic [2:0] funct3_mem;
  logic [4:0] rd_mem;
  logic reg_write_mem;

  logic [1:0] result_src_wb;
  logic [XLEN-1:0] pc_plus4_wb;
  logic [XLEN-1:0] alu_result_wb;
  logic [4:0] rd_wb;
  logic [XLEN-1:0] load_data_wb;
  logic reg_write_wb;

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

  // IF/ID
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      instr_id    <= '0;
      pc_id       <= '0;
      pc_plus4_id <= '0;
    end else begin
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
      .zero         (zero),
      .lt           (lt),
      .ltu          (ltu),
      .reg_write    (reg_write),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .pc_target_src(pc_target_src),
      .alu_src      (alu_src),
      .mem_write    (mem_write_dec),
      .result_src   (result_src),
      .pc_src       (pc_src),
      .alu_ctrl     (alu_ctrl)
  );

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
    end else begin
      pc_ex            <= pc_id;
      pc_plus4_ex      <= pc_plus4_id;
      funct3_ex        <= instr_id[14:12];
      imm_ext_ex       <= imm_ext;
      alu_a_src_ex     <= alu_a_src;
      pc_target_src_ex <= pc_target_src;
      alu_src_ex       <= alu_src;
      mem_write_ex     <= mem_write_dec;
      result_src_ex    <= result_src;
      alu_ctrl_ex      <= alu_ctrl;
      rs1_data_ex      <= rs1_data;
      rs2_data_ex      <= rs2_data;
      reg_write_ex     <= reg_write;
      rd_ex            <= instr_id[11:7];
    end
  end

  always_comb begin
    case (alu_a_src_ex)
      2'd0:    src_a = rs1_data_ex;
      2'd1:    src_a = pc_ex;
      2'd2:    src_a = '0;
      default: src_a = '0;
    endcase

    src_b = alu_src_ex ? imm_ext_ex : rs2_data_ex;
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

  // EX/MEM
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      reg_write_mem <= 1'b0;
      mem_write_mem <= 1'b0;
    end else begin
      alu_result_mem <= alu_result;
      pc_plus4_mem   <= pc_plus4_ex;
      write_data_mem <= rs2_data_ex;
      mem_write_mem  <= mem_write_ex;
      funct3_mem     <= funct3_ex;
      reg_write_mem  <= reg_write_ex;
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
    end else begin
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

  // Branch resolution deferred
  assign pc_next = pc_plus4;

`ifdef RISCV_FORMAL
  assign dbg_rs1_data = rs1_data;
  assign dbg_rd_wdata = result;
`endif

endmodule
