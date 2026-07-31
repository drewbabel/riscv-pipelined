module gpio_tb;

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;
  localparam int Width = 16;

  logic             clk = 0;
  logic             rst_n;
  logic             sel;
  logic [      3:0] wstrb;
  logic [ Xlen-1:0] addr;
  logic [ Xlen-1:0] wdata;
  logic [ Xlen-1:0] rdata;
  logic [Width-1:0] sw;
  logic [Width-1:0] led;

  gpio #(
      .XLEN (Xlen),
      .WIDTH(Width)
  ) dut (
      .clk    (clk),
      .core_en(1'b1),
      .rst_n  (rst_n),
      .sel    (sel),
      .wstrb  (wstrb),
      .addr   (addr),
      .wdata  (wdata),
      .rdata  (rdata),
      .sw     (sw),
      .led    (led)
  );

  always #5 clk = ~clk;

  task automatic do_reset();
    rst_n = 0;
    sel   = 0;
    wstrb = 0;
    addr  = 0;
    wdata = 0;
    sw    = 0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
  endtask

  task automatic mmio_write(input logic [Xlen-1:0] a, input logic [Xlen-1:0] d,
                            input logic [3:0] s);
    #1;
    sel   = 1;
    wstrb = s;
    addr  = a;
    wdata = d;
    @(posedge clk);
    #1;
    sel   = 0;
    wstrb = 0;
  endtask

  task automatic mmio_read(input logic [Xlen-1:0] a, output logic [Xlen-1:0] d);
    #1;
    sel  = 1;
    addr = a;
    #1;
    d   = rdata;
    sel = 0;
  endtask

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("%s: got %h exp %h", name, got, exp);
    end
  endtask

  logic [Xlen-1:0] got;

  initial begin
    $dumpfile("gpio_tb.vcd");
    $dumpvars(0, gpio_tb);
    do_reset();

    #1;
    check("led_at_reset", {16'b0, led}, '0);

    mmio_write(32'h0300_0000, 32'h0000_BEEF, 4'hF);
    #1;
    check("led_after_write", {16'b0, led}, 32'h0000_BEEF);

    mmio_read(32'h0300_0000, got);
    check("led_readback", got, 32'h0000_BEEF);

    sw = 16'hA5A5;
    mmio_read(32'h0300_0004, got);
    check("sw_read", got, 32'h0000_A5A5);

    mmio_write(32'h0300_0004, 32'h0000_1234, 4'hF);
    #1;
    check("sw_write_ignored", {16'b0, led}, 32'h0000_BEEF);

    mmio_write(32'h0300_0000, 32'h0000_0F0F, 4'h0);
    #1;
    check("no_strobe_ignored", {16'b0, led}, 32'h0000_BEEF);

    sel = 0;
    mmio_write(32'h0300_0000, 32'h0000_00FF, 4'hF);
    #1;
    check("led_second_write", {16'b0, led}, 32'h0000_00FF);

    #1;
    sel   = 0;
    wstrb = 4'hF;
    addr  = 32'h0300_0000;
    wdata = 32'h0000_DEAD;
    @(posedge clk);
    #1;
    wstrb = 0;
    check("deselected_write_ignored", {16'b0, led}, 32'h0000_00FF);

    rst_n = 0;
    @(posedge clk);
    #1;
    check("led_cleared_by_reset", {16'b0, led}, '0);
    rst_n = 1;

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

endmodule
