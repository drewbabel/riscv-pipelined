module pl_muldiv_tb ();

  localparam int Xlen = 32;
  localparam int Depth = 64;
  localparam int MaxCycles = 300;

  logic            clk = 1'b0;
  logic            rst_n;
  logic [Xlen-1:0] pc;
  logic [Xlen-1:0] alu_result;
  logic [Xlen-1:0] write_data;
  logic            mem_write;

  int checks = 0;
  int errors = 0;

  int              hold_run = 0;
  logic [Xlen-1:0] drain_x10, drain_x11;
  logic            drain_seen = 1'b0;

  always #5 clk = ~clk;

  top #(
      .XLEN (Xlen),
      .DEPTH(Depth)
  ) dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .pc        (pc),
      .alu_result(alu_result),
      .write_data(write_data),
      .mem_write (mem_write)
  );

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s = %0d (0x%08h), expected %0d (0x%08h)", name, got, got, exp, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic do_reset();
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  // Older instructions retire while divide holds EX
  always @(negedge clk) begin
    if (dut.riscv_pipelined_inst.datapath_inst.muldiv_hold) hold_run = hold_run + 1;
    else hold_run = 0;
    if (hold_run == 10 && !drain_seen) begin
      drain_seen = 1'b1;
      drain_x10  = dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[10];
      drain_x11  = dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[11];
    end
  end

  initial begin
    for (int i = 0; i < Depth; i++) dut.imem_inst.mem[i] = 32'h00000013;  // NOP fill
    $readmemh("tests/pl_muldiv.hex", dut.imem_inst.mem);
    do_reset();
    repeat (MaxCycles) @(posedge clk);

    check("x3 mul", dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[3], 32'd42);
    check("x6 divu", dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[6], 32'd6);
    check("x7 remu", dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[7], 32'd2);
    check("x9 div", dut.riscv_pipelined_inst.datapath_inst.regfile_inst.regfile_mem[9], 32'hFFFFFFFA);
    check("drain seen", 32'(drain_seen), 32'd1);
    check("x10 drained", drain_x10, 32'd99);
    check("x11 drained", drain_x11, 32'd88);

    verdict();
  end

endmodule
