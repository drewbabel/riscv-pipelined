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

  typedef enum logic {
    FETCH,
    ACCESS
  } state_t;

  state_t state;

  logic [XLEN-1:0] instr_q;
  logic [XLEN-1:0] instr_c;
  logic [     6:0] opcode;
  logic            is_mem;
  logic            fetch_ok;
  logic            core_step;
  logic [     3:0] core_wstrb;

  // Live then held
  assign instr_c     = (state == FETCH) ? instr : instr_q;
  assign opcode      = instr_c[6:0];
  assign is_mem      = (opcode == OpcodeLoad) || (opcode == OpcodeStore);

  assign fetch_ok    = (state == FETCH) && imem_ready;

  // Every word landed
  assign core_step   = core_en && ((fetch_ok && !is_mem) || ((state == ACCESS) && dmem_ready));

  assign imem_req    = (state == FETCH);
  assign dmem_req    = (state == ACCESS);

  // Request cycle only
  assign store_wstrb = (state == ACCESS) ? core_wstrb : 4'h0;
  assign mem_addr    = alu_result;

  always_ff @(posedge clk) begin
    if (!rst_n) state <= FETCH;
    else if (core_en) begin
      case (state)
        FETCH:   if (imem_ready && is_mem) state <= ACCESS;
        ACCESS:  if (dmem_ready) state <= FETCH;
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) instr_q <= '0;
    else if (core_en && fetch_ok && is_mem) instr_q <= instr;
  end

  riscv_single #(
      .XLEN(XLEN)
  ) riscv_single_inst (
      .clk        (clk),
      .core_en    (core_step),
      .cycle_en   (core_en),
      .rst_n      (rst_n),
      .instr      (instr_c),
      .read_data  (read_data),
      .timer_irq  (timer_irq),
      .pc         (pc),
      .mem_write  (mem_write),
      .alu_result (alu_result),
      .write_data (write_data),
      .store_wstrb(core_wstrb),
      .store_data (store_data)
  );

endmodule
