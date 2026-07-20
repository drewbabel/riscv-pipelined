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
    output logic [XLEN-1:0] dbg_rs1_data,
    output logic [XLEN-1:0] dbg_rd_wdata
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
      .dbg_rs1_data(dbg_rs1_data),
      .dbg_rd_wdata(dbg_rd_wdata)
`endif
  );

endmodule
