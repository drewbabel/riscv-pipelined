module csr_tb;
  import csr_pkg::*;

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;

  logic            clk = 0;
  logic            rst_n;
  logic            csr_access;
  logic [    11:0] csr_addr;
  logic [     2:0] funct3;
  logic [Xlen-1:0] rs1_data;
  logic [     4:0] zimm;
  logic [Xlen-1:0] pc;
  logic [Xlen-1:0] bad_addr;
  logic            exc_illegal;
  logic            exc_ecall;
  logic            exc_ebreak;
  logic            exc_instr_misaligned;
  logic            exc_load_misaligned;
  logic            exc_store_misaligned;
  logic            is_mret;
  logic            timer_irq;
  logic [Xlen-1:0] csr_rdata;
  logic            trap_taken;
  logic [Xlen-1:0] trap_vector;
  logic            mret_taken;
  logic [Xlen-1:0] mepc_out;

  logic [Xlen-1:0] exp_mscratch;

  always #5 clk = ~clk;


  csr #(
      .XLEN(Xlen)
  ) dut (
      .clk                 (clk),
      .core_en             (1'b1),
      .rst_n               (rst_n),
      .csr_access          (csr_access),
      .csr_addr            (csr_addr),
      .funct3              (funct3),
      .rs1_data            (rs1_data),
      .zimm                (zimm),
      .pc                  (pc),
      .bad_addr            (bad_addr),
      .exc_illegal         (exc_illegal),
      .exc_ecall           (exc_ecall),
      .exc_ebreak          (exc_ebreak),
      .exc_instr_misaligned(exc_instr_misaligned),
      .exc_load_misaligned (exc_load_misaligned),
      .exc_store_misaligned(exc_store_misaligned),
      .is_mret             (is_mret),
      .timer_irq           (timer_irq),
      .csr_rdata           (csr_rdata),
      .trap_taken          (trap_taken),
      .trap_vector         (trap_vector),
      .mret_taken          (mret_taken),
      .mepc_out            (mepc_out)
  );

  task automatic do_reset();
    rst_n = 0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
  endtask

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("%s: got %h exp %h", name, got, exp);
    end
  endtask

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  function automatic logic [2:0] op_of(input int idx);
    case (idx)
      0: op_of = Funct3Csrrw;
      1: op_of = Funct3Csrrs;
      2: op_of = Funct3Csrrc;
      3: op_of = Funct3Csrrwi;
      4: op_of = Funct3Csrrsi;
      default: op_of = Funct3Csrrci;
    endcase
  endfunction

  // read-modify-write, then commit and read back
  task automatic apply(input logic [2:0] op, input logic [Xlen-1:0] val);
    logic [Xlen-1:0] wsrc;
    wsrc = op[2] ? {{(Xlen - 5) {1'b0}}, val[4:0]} : val;
    case (op)
      Funct3Csrrw, Funct3Csrrwi: exp_mscratch = wsrc;
      Funct3Csrrs, Funct3Csrrsi: exp_mscratch = exp_mscratch | wsrc;
      Funct3Csrrc, Funct3Csrrci: exp_mscratch = exp_mscratch & ~wsrc;
      default: ;
    endcase
    #1;
    csr_addr   = MscratchAddr;
    funct3     = op;
    rs1_data   = val;
    zimm       = val[4:0];
    csr_access = 1;
    @(posedge clk);
    #1;
    csr_access = 0;
    check("mscratch", csr_rdata, exp_mscratch);
  endtask

  initial begin
    $dumpfile("csr_tb.vcd");
    $dumpvars(0, csr_tb);

    csr_access = 0;
    funct3 = 0;
    csr_addr = 0;
    rs1_data = 0;
    zimm = 0;
    is_mret = 0;
    timer_irq = 0;
    {exc_illegal, exc_ecall, exc_ebreak} = 0;
    {exc_instr_misaligned, exc_load_misaligned, exc_store_misaligned} = 0;
    do_reset();
    exp_mscratch = 0;

    apply(Funct3Csrrw, 32'hDEAD_BEEF);
    apply(Funct3Csrrs, 32'h0000_00F0);
    apply(Funct3Csrrc, 32'h0000_BEE0);
    apply(Funct3Csrrwi, 32'h0000_0015);
    apply(Funct3Csrrsi, 32'h0000_001F);
    apply(Funct3Csrrci, 32'h0000_000A);

    repeat (200) apply(op_of($urandom_range(0, 5)), $urandom);

    csr_addr = MtvecAddr;
    #1;
    check("mtvec_untouched", csr_rdata, 32'h0);

    // Mtip mirror check
    csr_addr   = MipAddr;
    funct3     = Funct3Csrrw;
    rs1_data   = 32'hFFFF_FFFF;
    csr_access = 1;
    @(posedge clk);
    #1;
    csr_access = 0;
    check("mip_mtip_masked", csr_rdata[Mtip], 1'b0);
    timer_irq = 1;
    #1;
    check("mip_mtip_line", csr_rdata[Mtip], 1'b1);
    timer_irq = 0;

    // mtvec mode check
    csr_addr   = MtvecAddr;
    funct3     = Funct3Csrrw;
    rs1_data   = 32'hFFFF_FFFF;
    csr_access = 1;
    @(posedge clk);
    #1;
    csr_access = 0;
    check("mtvec_wlrl", csr_rdata, 32'hFFFF_FFFF);
    check("mtvec_vector_aligned", trap_vector, 32'hFFFF_FFFC);

    verdict();
  end

endmodule
