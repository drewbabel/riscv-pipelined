module irq_formal
  import csr_pkg::*;
();

  localparam int XLEN = 32;

  logic            clk;
  logic            core_en;
  logic            rst_n;

  logic            csr_access;
  logic [    11:0] csr_addr;
  logic [     2:0] funct3;
  logic [XLEN-1:0] rs1_data;
  logic [     4:0] zimm;

  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] bad_addr;

  logic            exc_illegal;
  logic            exc_ecall;
  logic            exc_ebreak;
  logic            exc_instr_misaligned;
  logic            exc_load_misaligned;
  logic            exc_store_misaligned;

  logic            is_mret;
  logic            timer_irq;

  logic [XLEN-1:0] csr_rdata;
  logic            trap_taken;
  logic [XLEN-1:0] trap_vector;
  logic            mret_taken;
  logic [XLEN-1:0] mepc_out;

  logic [XLEN-1:0] dbg_csr_wdata;
  logic [XLEN-1:0] dbg_mscratch;
  logic [XLEN-1:0] dbg_mstatus;
  logic [XLEN-1:0] dbg_mtvec;
  logic [XLEN-1:0] dbg_mepc;
  logic [XLEN-1:0] dbg_mcause;
  logic [XLEN-1:0] dbg_mtval;
  logic [XLEN-1:0] dbg_mie;
  logic [XLEN-1:0] dbg_mip;
  logic [XLEN-1:0] dbg_mcycle;
  logic [XLEN-1:0] dbg_minstret;
  logic [XLEN-1:0] dbg_mcycleh;
  logic [XLEN-1:0] dbg_minstreth;

  csr #(
      .XLEN(XLEN)
  ) dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .csr_access(csr_access),
      .csr_addr(csr_addr),
      .funct3(funct3),
      .rs1_data(rs1_data),
      .zimm(zimm),
      .pc(pc),
      .bad_addr(bad_addr),
      .exc_illegal(exc_illegal),
      .exc_ecall(exc_ecall),
      .exc_ebreak(exc_ebreak),
      .exc_instr_misaligned(exc_instr_misaligned),
      .exc_load_misaligned(exc_load_misaligned),
      .exc_store_misaligned(exc_store_misaligned),
      .is_mret(is_mret),
      .timer_irq(timer_irq),
      .csr_rdata(csr_rdata),
      .trap_taken(trap_taken),
      .trap_vector(trap_vector),
      .mret_taken(mret_taken),
      .mepc_out(mepc_out),
      .dbg_csr_wdata(dbg_csr_wdata),
      .dbg_mscratch(dbg_mscratch),
      .dbg_mstatus(dbg_mstatus),
      .dbg_mtvec(dbg_mtvec),
      .dbg_mepc(dbg_mepc),
      .dbg_mcause(dbg_mcause),
      .dbg_mtval(dbg_mtval),
      .dbg_mie(dbg_mie),
      .dbg_mip(dbg_mip),
      .dbg_mcycle(dbg_mcycle),
      .dbg_minstret(dbg_minstret),
      .dbg_mcycleh(dbg_mcycleh),
      .dbg_minstreth(dbg_minstreth)
  );

  logic f_past_valid = 1'b0;
  always @(posedge clk) f_past_valid <= 1'b1;

  logic exc_any;
  assign exc_any = exc_illegal | exc_ecall | exc_ebreak | exc_instr_misaligned
                 | exc_load_misaligned | exc_store_misaligned;

  logic irq_ready;
  assign irq_ready = timer_irq & dbg_mstatus[MstatusMie] & dbg_mie[Mtie];

  // Reachable inputs
  always @(posedge clk) begin
    assume (rst_n);
    assume (!(is_mret && csr_access));
  end

  always @(posedge clk) begin
    if (f_past_valid) begin
      // Arrival
      if (irq_ready && !exc_any) assert (trap_taken);

      // Masking
      if (!exc_any && !irq_ready) assert (!trap_taken);

      // Entry state
      if ($past(irq_ready && !exc_any && core_en)) begin
        assert (dbg_mepc == $past(pc));
        assert (dbg_mcause == {1'b1, 31'(CauseMachineTimerIrq)});
        assert (dbg_mstatus[MstatusMie] == 1'b0);
        assert (dbg_mstatus[MstatusMpie] == $past(dbg_mstatus[MstatusMie]));
        assert (trap_vector == {dbg_mtvec[31:2], 2'b00});
      end

      // Priority
      if ($past(exc_any && timer_irq && core_en)) assert (!dbg_mcause[31]);

      // Mret
      if ($past(is_mret && !trap_taken && core_en))
        assert (dbg_mstatus[MstatusMie] == $past(dbg_mstatus[MstatusMpie]));
    end
  end

endmodule
