module dmem_tb ();

  localparam int XLEN = 32;
  localparam int DEPTH = 64;
  localparam int AddrWidth = $clog2(DEPTH);

  int checks = 0;
  int errors = 0;

  logic clk = 1'b0;
  logic [3:0] wstrb;
  logic [XLEN-1:0] addr;
  logic [XLEN-1:0] wdata;
  logic [XLEN-1:0] rdata;

  logic [XLEN-1:0] shadow[DEPTH];

  always #5 clk = ~clk;

  dmem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) dut (
      .clk  (clk),
      .wstrb(wstrb),
      .addr (addr),
      .wdata(wdata),
      .rdata(rdata)
  );

  task automatic write_mem(input logic [XLEN-1:0] a, input logic [XLEN-1:0] data);
    #1;
    addr  = a;
    wdata = data;
    wstrb = 4'hF;
    @(posedge clk);
    @(negedge clk);
    wstrb = 4'h0;
  endtask

  // Drive a cycle with wstrb zero, memory must not change
  task automatic write_blocked(input logic [XLEN-1:0] a, input logic [XLEN-1:0] data);
    #1;
    addr  = a;
    wdata = data;
    wstrb = 4'h0;
    @(posedge clk);
    @(negedge clk);
  endtask

  task automatic check_read(input logic [XLEN-1:0] a);
    logic [XLEN-1:0] exp;
    #1;
    addr = a;
    #1;
    exp = shadow[a[AddrWidth+1:2]];
    checks++;
    if (rdata !== exp) begin
      errors++;
      $display("Read mismatch addr=%h exp=%h got=%h", a, exp, rdata);
    end
  endtask

  task automatic verdict();
    @(posedge clk);
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  // Reference model
  always @(posedge clk) begin
    if (|wstrb) shadow[addr[AddrWidth+1:2]] <= wdata;
  end

  initial begin
    $dumpfile("dmem_tb.vcd");
    $dumpvars(0, dmem_tb);

    // Zero all words to define reads
    for (int i = 0; i < DEPTH; i++) write_mem(XLEN'(i * 4), '0);

    // Write word, read it back
    write_mem(32'h00000004, 32'hDEADBEEF);
    check_read(32'h00000004);

    // A second word must not disturb the first
    write_mem(32'h00000008, 32'hCAFEF00D);
    check_read(32'h00000008);
    check_read(32'h00000004);

    // we low: the write must not land
    write_blocked(32'h00000004, 32'hFFFFFFFF);
    check_read(32'h00000004);

    // Randomized write then read sweep
    for (int i = 0; i < 1000; i++) begin
      int w;
      w = $urandom % DEPTH;
      write_mem(XLEN'(w * 4), XLEN'($urandom));
      w = $urandom % DEPTH;
      check_read(XLEN'(w * 4));
    end

    verdict();
  end

endmodule
