module sc_core_top
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
    input  logic            imem_ready,
    input  logic            dmem_ready,
    output logic            imem_req,
    output logic            dmem_req,
    output logic [XLEN-1:0] pc,
    output logic            mem_write,
    output logic [XLEN-1:0] alu_result,
    output logic [XLEN-1:0] write_data,
    output logic [     3:0] store_wstrb,
    output logic [XLEN-1:0] store_data,
    output logic [XLEN-1:0] mem_addr
);

  typedef enum logic [1:0] {
    FETCH,
    ACCESS,
    STEP
  } state_t;

  state_t state;

  logic [XLEN-1:0] instr_h;
  logic [XLEN-1:0] rdata_h;
  logic            irq_h;
  logic [     6:0] opcode;
  logic            is_mem;
  logic            instr_cap;
  logic            data_cap;
  logic            core_step;
  logic [     3:0] core_wstrb;

  // Live at capture
  assign opcode      = instr[6:0];
  assign is_mem      = (opcode == OpcodeLoad) || (opcode == OpcodeStore);

  assign instr_cap   = core_en && (state == FETCH) && imem_ready;
  assign data_cap    = core_en && (state == ACCESS) && dmem_ready;

  // Never a capture
  assign core_step   = core_en && (state == STEP);

  assign imem_req    = (state == FETCH);
  assign dmem_req    = (state == ACCESS);

  // Request cycle only
  assign store_wstrb = (state == ACCESS) ? core_wstrb : 4'h0;
  assign mem_addr    = alu_result;

  always_ff @(posedge clk) begin
    if (!rst_n) state <= FETCH;
    else if (instr_cap && is_mem) state <= ACCESS;
    else if (instr_cap) state <= STEP;
    else if (data_cap) state <= STEP;
    else if (core_step) state <= FETCH;
  end

  // Gated cone sources
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      instr_h <= '0;
      irq_h   <= 1'b0;
    end else if (instr_cap) begin
      instr_h <= instr;
      irq_h   <= timer_irq;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) rdata_h <= '0;
    else if (data_cap) rdata_h <= read_data;
  end

  riscv_single #(
      .XLEN(XLEN)
  ) riscv_single_inst (
      .clk        (clk),
      .core_en    (core_step),
      .cycle_en   (core_en),
      .rst_n      (rst_n),
      .instr      (instr_h),
      .read_data  (rdata_h),
      .timer_irq  (irq_h),
      .pc         (pc),
      .mem_write  (mem_write),
      .alu_result (alu_result),
      .write_data (write_data),
      .store_wstrb(core_wstrb),
      .store_data (store_data)
  );

endmodule
