module tick_gen_tb ();

  localparam int DIVISOR = 4;

  int   errors = 0;
  int   checks = 0;

  logic clk = 0;
  logic rst_n;
  logic clr = 0;
  logic tick;

  int   phase;  // Reference divisor phase: rst_n or clr clears it, else count and wrap

  always #5 clk = ~clk;

  tick_gen #(
      .DIVISOR(DIVISOR)
  ) dut (
      .clk(clk),
      .core_en(1'b1),
      .rst_n(rst_n),
      .clr(clr),
      .tick(tick)
  );

  task automatic do_reset();
    rst_n = 1'b0;
    clr   = 1'b0;
    @(posedge clk);
    @(posedge clk);
    #1 rst_n = 1'b1;
  endtask  // Automatic


  task automatic do_verdict();
    if (errors == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, errors);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    end
    $finish;
  endtask  // Automatic

  task automatic check(input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("t=%0t mismatch: got=%b, exp=%b", $time, got, exp);
    end
  endtask  // Automatic

  // Pulse clr high for one clock to force a phase resync
  task automatic pulse_clr();
    #1 clr = 1'b1;
    @(posedge clk);
    #1 clr = 1'b0;
  endtask  // Automatic


  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tick_gen_tb);
    do_reset();

    // Free-run
    repeat (100) @(posedge clk);

    // Resync mid-phase: clr at an arbitrary offset, tick must realign
    repeat (2) @(posedge clk);
    pulse_clr();
    repeat (100) @(posedge clk);

    // Back-to-back clr on consecutive clocks
    pulse_clr();
    pulse_clr();
    repeat (50) @(posedge clk);

    do_verdict();
  end

  // Reference model
  always @(posedge clk) begin
    if (!rst_n) phase <= 0;
    else if (clr) phase <= 0;
    else phase <= (phase == DIVISOR - 1) ? 0 : phase + 1;
  end

  always @(negedge clk) begin
    if (rst_n) check(tick, (phase == DIVISOR - 1));
  end
endmodule
