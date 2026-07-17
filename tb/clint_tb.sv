module clint_tb;

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;

  logic            clk = 0;
  logic            rst_n;
  logic            sel;
  logic [     3:0] wstrb;
  logic [Xlen-1:0] addr;
  logic [Xlen-1:0] wdata;
  logic [Xlen-1:0] rdata;
  logic            timer_irq;

  clint #(
      .XLEN(Xlen)
  ) dut (
      .clk      (clk),
      .core_en  (1'b1),
      .rst_n    (rst_n),
      .sel      (sel),
      .wstrb    (wstrb),
      .addr     (addr),
      .wdata    (wdata),
      .rdata    (rdata),
      .timer_irq(timer_irq)
  );

  always #5 clk = ~clk;

  task automatic do_reset();
    rst_n = 0;
    sel   = 0;
    wstrb = 0;
    addr  = 0;
    wdata = 0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
  endtask

  task automatic mmio_write(input logic [Xlen-1:0] a, input logic [Xlen-1:0] d);
    #1;
    sel   = 1;
    wstrb = 4'hF;
    addr  = a;
    wdata = d;
    @(posedge clk);
    #1;
    sel   = 0;
    wstrb = 0;
  endtask

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("%s: got %h exp %h", name, got, exp);
    end
  endtask

  initial begin
    $dumpfile("clint_tb.vcd");
    $dumpvars(0, clint_tb);
    do_reset();

    #1;
    check("irq_at_reset", timer_irq, 32'd0);  // mtimecmp resets to max

    mmio_write(32'h0000_4000, 32'd50);
    mmio_write(32'h0000_4004, 32'd0);

    #1;
    sel  = 1;
    addr = 32'h0000_4000;
    #1;
    check("mtimecmp_readback", rdata, 32'd50);
    sel = 0;

    #1;
    check("irq_before_compare", timer_irq, 32'd0);

    repeat (60) @(posedge clk);
    #1;
    check("irq_after_compare", timer_irq, 32'd1);

    #1;
    sel   = 1;
    wstrb = 4'b0010;  // lane 1 only
    addr  = 32'h0000_4000;
    wdata = 32'h0000_AA00;
    @(posedge clk);
    #1;
    sel   = 0;
    wstrb = 0;
    #1;
    sel  = 1;
    addr = 32'h0000_4000;
    #1;
    check("mtimecmp_byte_write", rdata, 32'h0000_AA32);
    sel = 0;

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

endmodule
