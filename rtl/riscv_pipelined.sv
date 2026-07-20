module riscv_pipelined
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

  datapath #(
      .XLEN(XLEN)
  ) datapath_inst (
      .clk        (clk),
      .core_en    (core_en),
      .rst_n      (rst_n),
      .instr      (instr),
      .read_data  (read_data),
      .pc         (pc),
      .mem_write  (mem_write),
      .alu_result (alu_result),
      .write_data (write_data),
      .store_wstrb(store_wstrb),
      .store_data (store_data),
      .mem_addr   (mem_addr)
`ifdef RISCV_FORMAL
      ,
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
`endif
  );

endmodule
