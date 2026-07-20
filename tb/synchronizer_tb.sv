module synchronizer_tb ();

  int   errors = 0;
  int   checks = 0;

  logic clk = 0;
  logic d;
  logic q;

  always #5 clk = ~clk;

  synchronizer dut (
      .clk(clk),
      .core_en(1'b1),
      .d(d),
      .q(q)
  );

  logic d1;
  logic d2;

  task automatic check(input string name, input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("t=%0t %s mismatch: got=%b  exp=%b", $time, name, got, exp);
    end
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, errors);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    end
    $finish;
  endtask  // Automatic

  // Stimulus
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, synchronizer_tb);

    d = 1'b0;
    @(posedge clk);
    @(posedge clk);

    repeat (100) begin
      #1 d = 1'($urandom);
      @(posedge clk);
    end

    @(posedge clk);

    verdict();
  end

  // Reference model
  always @(posedge clk) begin
    d1 <= d;
    d2 <= d1;
  end

  // Comparison to DUT
  always @(negedge clk) begin
    check("ff2", q, d2);
  end

endmodule
