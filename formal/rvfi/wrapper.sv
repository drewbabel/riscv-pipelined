module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);

  // Free solver inputs
  (* keep *)`rvformal_rand_reg [31:0] instr;
  (* keep *)`rvformal_rand_reg [31:0] read_data;

  (* keep *)logic              [31:0] pc;
  (* keep *)logic              [31:0] alu_result;
  (* keep *)logic              [31:0] write_data;
  (* keep *)logic              [ 3:0] store_wstrb;
  (* keep *)logic              [31:0] store_data;
  (* keep *)logic              [31:0] mem_addr;
  (* keep *)logic                     mem_write;

  // Retirement taps
  (* keep *)logic                     dbg_valid;
  (* keep *)logic              [31:0] dbg_insn;
  (* keep *)logic              [31:0] dbg_pc_rdata;
  (* keep *)logic              [31:0] dbg_pc_wdata;
  (* keep *)logic              [31:0] dbg_rs1_rdata;
  (* keep *)logic              [31:0] dbg_rs2_rdata;
  (* keep *)logic              [31:0] dbg_rd_wdata;
  (* keep *)logic                     dbg_reg_write;
  (* keep *)logic              [31:0] dbg_mem_addr;
  (* keep *)logic              [ 3:0] dbg_mem_wmask;
  (* keep *)logic              [31:0] dbg_mem_wdata;
  (* keep *)logic              [31:0] dbg_mem_rdata;
  (* keep *)logic                     dbg_trap;
  (* keep *)logic              [31:0] dbg_csr_wdata;
  (* keep *)logic              [31:0] dbg_mscratch;
  (* keep *)logic              [31:0] dbg_mstatus;
  (* keep *)logic              [31:0] dbg_mtvec;
  (* keep *)logic              [31:0] dbg_mepc;
  (* keep *)logic              [31:0] dbg_mcause;
  (* keep *)logic              [31:0] dbg_mtval;
  (* keep *)logic              [31:0] dbg_mie;
  (* keep *)logic              [31:0] dbg_mip;
  (* keep *)logic              [31:0] dbg_mcycle;
  (* keep *)logic              [31:0] dbg_minstret;
  (* keep *)logic              [31:0] dbg_mcycleh;
  (* keep *)logic              [31:0] dbg_minstreth;

  riscv_pipelined uut (
      .clk          (clock),
      .core_en      (1'b1),
      .rst_n        (!reset),
      .instr        (instr),
      .read_data    (read_data),
      .pc           (pc),
      .mem_write    (mem_write),
      .alu_result   (alu_result),
      .write_data   (write_data),
      .store_wstrb  (store_wstrb),
      .store_data   (store_data),
      .mem_addr     (mem_addr),
      .dbg_valid    (dbg_valid),
      .dbg_insn     (dbg_insn),
      .dbg_pc_rdata (dbg_pc_rdata),
      .dbg_pc_wdata (dbg_pc_wdata),
      .dbg_rs1_rdata(dbg_rs1_rdata),
      .dbg_rs2_rdata(dbg_rs2_rdata),
      .dbg_rd_wdata (dbg_rd_wdata),
      .dbg_reg_write(dbg_reg_write),
      .dbg_mem_addr (dbg_mem_addr),
      .dbg_mem_wmask(dbg_mem_wmask),
      .dbg_mem_wdata(dbg_mem_wdata),
      .dbg_mem_rdata(dbg_mem_rdata),
      .dbg_trap     (dbg_trap),
      .dbg_csr_wdata(dbg_csr_wdata),
      .dbg_mscratch (dbg_mscratch),
      .dbg_mstatus  (dbg_mstatus),
      .dbg_mtvec    (dbg_mtvec),
      .dbg_mepc     (dbg_mepc),
      .dbg_mcause   (dbg_mcause),
      .dbg_mtval    (dbg_mtval),
      .dbg_mie      (dbg_mie),
      .dbg_mip      (dbg_mip),
      .dbg_mcycle   (dbg_mcycle),
      .dbg_minstret (dbg_minstret),
      .dbg_mcycleh  (dbg_mcycleh),
      .dbg_minstreth(dbg_minstreth)
  );

  logic [63:0] order_q;
  logic        rd_nonzero;
  logic [ 3:0] rmask_c;

  always_ff @(posedge clock) begin
    if (reset) order_q <= 64'd0;
    else if (dbg_valid) order_q <= order_q + 64'd1;
  end

  assign rvfi_valid     = dbg_valid && !reset;
  assign rvfi_order     = order_q;
  assign rvfi_insn      = dbg_insn;
  assign rvfi_trap      = dbg_trap;
  assign rvfi_halt      = 1'b0;
  assign rvfi_intr      = 1'b0;
  assign rvfi_mode      = 2'd3;
  assign rvfi_ixl       = 2'd1;

  assign rd_nonzero     = dbg_reg_write && (dbg_insn[11:7] != 5'd0);
  assign rvfi_rs1_addr  = dbg_insn[19:15];
  assign rvfi_rs2_addr  = dbg_insn[24:20];
  assign rvfi_rs1_rdata = dbg_rs1_rdata;
  assign rvfi_rs2_rdata = dbg_rs2_rdata;
  assign rvfi_rd_addr   = rd_nonzero ? dbg_insn[11:7] : 5'd0;
  assign rvfi_rd_wdata  = rd_nonzero ? dbg_rd_wdata : 32'd0;

  assign rvfi_pc_rdata  = dbg_pc_rdata;
  assign rvfi_pc_wdata  = dbg_pc_wdata;

  assign rvfi_mem_addr  = {dbg_mem_addr[31:2], 2'b00};
  assign rvfi_mem_wmask = dbg_mem_wmask;
  assign rvfi_mem_rmask = rmask_c;
  assign rvfi_mem_rdata = dbg_mem_rdata;
  assign rvfi_mem_wdata = dbg_mem_wdata;

  always_comb begin
    rmask_c = 4'b0000;
    if (dbg_insn[6:0] == 7'b0000011) begin
      case (dbg_insn[14:12])
        3'b000, 3'b100: rmask_c = 4'b0001 << dbg_mem_addr[1:0];
        3'b001, 3'b101: rmask_c = 4'b0011 << dbg_mem_addr[1:0];
        3'b010:         rmask_c = 4'b1111;
        default:        rmask_c = 4'b0000;
      endcase
    end
  end

  // Shadow CSR to retirement
  logic [31:0] mscratch_pre, mstatus_pre, mtvec_pre, mepc_pre, mcause_pre;
  logic [31:0] mtval_pre, mie_pre, mip_pre, mcycle_pre, minstret_pre;
  logic [31:0] mcycleh_pre, minstreth_pre;
  logic [31:0] mscratch_post, mstatus_post, mtvec_post, mepc_post, mcause_post;
  logic [31:0] mtval_post, mie_post, mip_post, mcycle_post, minstret_post;
  logic [31:0] mcycleh_post, minstreth_post;

  always_ff @(posedge clock) begin
    mscratch_post  <= dbg_mscratch;
    mstatus_post   <= dbg_mstatus;
    mtvec_post     <= dbg_mtvec;
    mepc_post      <= dbg_mepc;
    mcause_post    <= dbg_mcause;
    mtval_post     <= dbg_mtval;
    mie_post       <= dbg_mie;
    mip_post       <= dbg_mip;
    mcycle_post    <= dbg_mcycle;
    minstret_post  <= dbg_minstret;
    mcycleh_post   <= dbg_mcycleh;
    minstreth_post <= dbg_minstreth;

    mscratch_pre   <= mscratch_post;
    mstatus_pre    <= mstatus_post;
    mtvec_pre      <= mtvec_post;
    mepc_pre       <= mepc_post;
    mcause_pre     <= mcause_post;
    mtval_pre      <= mtval_post;
    mie_pre        <= mie_post;
    mip_pre        <= mip_post;
    mcycle_pre     <= mcycle_post;
    minstret_pre   <= minstret_post;
    mcycleh_pre    <= mcycleh_post;
    minstreth_pre  <= minstreth_post;
  end

  logic csr_op;
  assign csr_op = dbg_insn[6:0] == 7'b1110011 && dbg_insn[14:12] != 3'b000;

`ifdef RISCV_FORMAL_CSR_MSCRATCH
  logic is_mscratch;
  assign is_mscratch = csr_op && dbg_insn[31:20] == 12'h340;
  assign rvfi_csr_mscratch_rmask = is_mscratch ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mscratch_wmask = (mscratch_pre != mscratch_post) ? 32'hFFFFFFFF : (is_mscratch ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mscratch_rdata = mscratch_pre;
  assign rvfi_csr_mscratch_wdata = mscratch_post;
`endif
`ifdef RISCV_FORMAL_CSR_MSTATUS
  logic is_mstatus;
  assign is_mstatus = csr_op && dbg_insn[31:20] == 12'h300;
  assign rvfi_csr_mstatus_rmask = is_mstatus ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mstatus_wmask = (mstatus_pre != mstatus_post) ? 32'hFFFFFFFF : (is_mstatus ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mstatus_rdata = mstatus_pre;
  assign rvfi_csr_mstatus_wdata = mstatus_post;
`endif
`ifdef RISCV_FORMAL_CSR_MTVEC
  logic is_mtvec;
  assign is_mtvec = csr_op && dbg_insn[31:20] == 12'h305;
  assign rvfi_csr_mtvec_rmask = is_mtvec ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mtvec_wmask = (mtvec_pre != mtvec_post) ? 32'hFFFFFFFF : (is_mtvec ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mtvec_rdata = mtvec_pre;
  assign rvfi_csr_mtvec_wdata = mtvec_post;
`endif
`ifdef RISCV_FORMAL_CSR_MEPC
  logic is_mepc;
  assign is_mepc = csr_op && dbg_insn[31:20] == 12'h341;
  assign rvfi_csr_mepc_rmask = is_mepc ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mepc_wmask = (mepc_pre != mepc_post) ? 32'hFFFFFFFF : (is_mepc ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mepc_rdata = mepc_pre;
  assign rvfi_csr_mepc_wdata = mepc_post;
`endif
`ifdef RISCV_FORMAL_CSR_MCAUSE
  logic is_mcause;
  assign is_mcause = csr_op && dbg_insn[31:20] == 12'h342;
  assign rvfi_csr_mcause_rmask = is_mcause ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mcause_wmask = (mcause_pre != mcause_post) ? 32'hFFFFFFFF : (is_mcause ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mcause_rdata = mcause_pre;
  assign rvfi_csr_mcause_wdata = mcause_post;
`endif
`ifdef RISCV_FORMAL_CSR_MTVAL
  logic is_mtval;
  assign is_mtval = csr_op && dbg_insn[31:20] == 12'h343;
  assign rvfi_csr_mtval_rmask = is_mtval ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mtval_wmask = (mtval_pre != mtval_post) ? 32'hFFFFFFFF : (is_mtval ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mtval_rdata = mtval_pre;
  assign rvfi_csr_mtval_wdata = mtval_post;
`endif
`ifdef RISCV_FORMAL_CSR_MIE
  logic is_mie;
  assign is_mie = csr_op && dbg_insn[31:20] == 12'h304;
  assign rvfi_csr_mie_rmask = is_mie ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mie_wmask = (mie_pre != mie_post) ? 32'hFFFFFFFF : (is_mie ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mie_rdata = mie_pre;
  assign rvfi_csr_mie_wdata = mie_post;
`endif
`ifdef RISCV_FORMAL_CSR_MIP
  logic is_mip;
  assign is_mip = csr_op && dbg_insn[31:20] == 12'h344;
  assign rvfi_csr_mip_rmask = is_mip ? 32'hFFFFFFFF : 32'd0;
  assign rvfi_csr_mip_wmask = (mip_pre != mip_post) ? 32'hFFFFFFFF : (is_mip ? 32'hFFFFFFFF : 32'd0);
  assign rvfi_csr_mip_rdata = mip_pre;
  assign rvfi_csr_mip_wdata = mip_post;
`endif
`ifdef RISCV_FORMAL_CSR_MCYCLE
  logic is_mcycle_lo;
  assign is_mcycle_lo = csr_op && dbg_insn[31:20] == 12'hB00;
  logic is_mcycle_hi;
  assign is_mcycle_hi = csr_op && dbg_insn[31:20] == 12'hB80;
  assign rvfi_csr_mcycle_rmask = {is_mcycle_hi ? 32'hFFFFFFFF : 32'd0, is_mcycle_lo ? 32'hFFFFFFFF : 32'd0};
  assign rvfi_csr_mcycle_wmask = {is_mcycle_hi ? 32'hFFFFFFFF : 32'd0, is_mcycle_lo ? 32'hFFFFFFFF : 32'd0};
  assign rvfi_csr_mcycle_rdata = {mcycleh_pre, mcycle_pre};
  assign rvfi_csr_mcycle_wdata = {mcycleh_post, mcycle_post};
`endif
`ifdef RISCV_FORMAL_CSR_MINSTRET
  logic is_minstret_lo;
  assign is_minstret_lo = csr_op && dbg_insn[31:20] == 12'hB02;
  logic is_minstret_hi;
  assign is_minstret_hi = csr_op && dbg_insn[31:20] == 12'hB82;
  assign rvfi_csr_minstret_rmask = {is_minstret_hi ? 32'hFFFFFFFF : 32'd0, is_minstret_lo ? 32'hFFFFFFFF : 32'd0};
  assign rvfi_csr_minstret_wmask = {is_minstret_hi ? 32'hFFFFFFFF : 32'd0, is_minstret_lo ? 32'hFFFFFFFF : 32'd0};
  assign rvfi_csr_minstret_rdata = {minstreth_pre, minstret_pre};
  assign rvfi_csr_minstret_wdata = {minstreth_post, minstret_post};
`endif

endmodule
