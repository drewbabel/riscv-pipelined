module imem_tb ();

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;
  localparam int DEPTH = 64;

  logic [Xlen-1:0] addr;
  logic [Xlen-1:0] instr;

  imem #(
      .XLEN (Xlen),
      .DEPTH(DEPTH)
  ) dut (
      .addr (addr),
      .instr(instr)
  );

  task automatic do_verdict();
    if (errors == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, errors);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    end
    $finish;
  endtask  // Automatic

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("%s mismatch: got %b, expected %b at time %0t", name, got, exp, $time);
    end
  endtask

  initial begin
    $dumpfile("imem_tb.vcd");
    $dumpvars(0, imem_tb);

    // Initialize memory with some test values
    for (int i = 0; i < DEPTH; i++) begin
      dut.mem[i] = i * 4;
    end

    // Test reading from memory
    for (int i = 0; i < DEPTH; i++) begin
      addr = i * 4;
      #1;
      check("Memory read", instr, Xlen'(i * 4));
    end

    do_verdict();
  end

endmodule
