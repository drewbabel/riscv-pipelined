module pc_tb ();
  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;
  localparam logic [Xlen-1:0] ResetAddr = '0;

  logic clk = 0;
  logic rst_n;
  logic [Xlen-1:0] pc_next;
  logic [Xlen-1:0] pc_q;

  always #5 clk = ~clk;

  pc #(
      .XLEN(Xlen),
      .RESET_ADDR(ResetAddr)
  ) dut (
      .clk(clk),
      .core_en(1'b1),
      .rst_n(rst_n),
      .pc_next(pc_next),
      .pc_q(pc_q)
  );

  task automatic do_reset();
    rst_n <= 0;
    repeat (2) @(posedge clk);
    rst_n <= 1;
  endtask  // Automatic

  task automatic do_verdict();
    @(posedge clk);
    if (errors == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, errors);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    end
    $finish;
  endtask  // Automatic

  task automatic pc_suite(input logic [Xlen-1:0] exp_pc, input logic reg_check);
    pc_next = exp_pc;
    @(posedge clk);
    #1;
    if (reg_check) pc_next = (Xlen)'($urandom());
    #1;
    checks++;
    if (rst_n == 0) begin
      if (pc_q !== ResetAddr) begin
        errors++;
        $display("Reset mismatch: pc_q=%h, expected=%h", pc_q, ResetAddr);
      end
    end else if (pc_q !== exp_pc) begin
      errors++;
      $display("pc_q mismatch: pc_q=%h, expected=%h", pc_q, exp_pc);
    end
  endtask  // Automatic

  initial begin
    $dumpfile("pc_tb.vcd");
    $dumpvars(0, pc_tb);
    do_reset();

    for (int i = 0; i < 1000; i++) begin
      if ((i % 6) == 0) rst_n = 0;
      else rst_n = 1;

      pc_suite((Xlen)'($urandom()), 1'($urandom()));
    end

    do_verdict();
  end
endmodule
