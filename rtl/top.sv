module top #(
    parameter int XLEN  = 32,
    parameter int DEPTH = 64
) (
    input  logic            clk,
    input  logic            rst_n,
    output logic [XLEN-1:0] pc,
    output logic [XLEN-1:0] alu_result,
    output logic [XLEN-1:0] write_data,
    output logic            mem_write
);

  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] read_data;
  logic [     3:0] store_wstrb;
  logic [XLEN-1:0] store_data;
  logic [XLEN-1:0] mem_addr;

  riscv_pipelined #(
      .XLEN(XLEN)
  ) riscv_pipelined_inst (
      .clk        (clk),
      .core_en    (1'b1),
      .rst_n      (rst_n),
      .instr      (instr),
      .read_data  (read_data),
      .timer_irq  (1'b0),
      .pc         (pc),
      .mem_write  (mem_write),
      .alu_result (alu_result),
      .write_data (write_data),
      .store_wstrb(store_wstrb),
      .store_data (store_data),
      .mem_addr   (mem_addr)
  );

  imem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) imem_inst (
      .clk  (clk),
      .we   (1'b0),
      .waddr('0),
      .wdata('0),
      .addr (pc),
      .instr(instr)
  );

  dmem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) dmem_inst (
      .clk  (clk),
      .wstrb(store_wstrb),
      .addr (mem_addr),
      .wdata(store_data),
      .rdata(read_data)
  );

endmodule
