module mem_delay_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int Depth = 256;
  localparam int Latency = 5;

  logic clk;
  logic core_en;
  logic rst_n;

  logic                req_valid;
  logic                req_rw;
  logic [    Xlen-1:0] req_addr;
  logic [LineBits-1:0] req_wdata;
  logic [LineBits-1:0] resp_rdata;
  logic                resp_ready;

  logic                boot_we;
  logic [    Xlen-1:0] boot_addr;
  logic [    Xlen-1:0] boot_wdata;

  int checks = 0;
  int errors = 0;
  int waited = 0;

  always #5 clk = ~clk;

  mem_delay #(
      .XLEN(Xlen),
      .DEPTH(Depth),
      .Latency(Latency)
  ) dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .req_valid(req_valid),
      .req_rw(req_rw),
      .req_addr(req_addr),
      .req_wdata(req_wdata),
      .resp_rdata(resp_rdata),
      .resp_ready(resp_ready),
      .boot_we(boot_we),
      .boot_addr(boot_addr),
      .boot_wdata(boot_wdata)
  );

  task automatic check(input string name, input logic [LineBits-1:0] got,
                       input logic [LineBits-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s: got %h exp %h", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic check_int(input string name, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      $error("%s: got %0d exp %0d", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic do_reset();
    rst_n = 1'b0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask  // Automatic

  task automatic boot_word(input logic [Xlen-1:0] addr, input logic [Xlen-1:0] data);
    #1;
    boot_we    = 1'b1;
    boot_addr  = addr;
    boot_wdata = data;
    @(posedge clk);
    #1;
    boot_we = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic request(input logic rw, input logic [Xlen-1:0] addr,
                         input logic [LineBits-1:0] wdata);
    #1;
    req_valid = 1'b1;
    req_rw    = rw;
    req_addr  = addr;
    req_wdata = wdata;
    waited    = 0;
    @(posedge clk);
    while (!resp_ready) begin
      waited++;
      @(posedge clk);
      if (waited > 100) $fatal(1, "resp_ready never arrived");
    end
    #1;
    req_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, mem_delay_tb);

    clk       = 1'b0;
    core_en   = 1'b1;
    rst_n     = 1'b1;
    req_valid = 1'b0;
    req_rw    = 1'b0;
    req_addr  = '0;
    req_wdata = '0;
    boot_we   = 1'b0;
    boot_addr = '0;
    boot_wdata = '0;

    do_reset();

    // Boot line
    boot_word(32'h0000_0000, 32'hAAAA_0000);
    boot_word(32'h0000_0004, 32'hAAAA_0001);
    boot_word(32'h0000_0008, 32'hAAAA_0002);
    boot_word(32'h0000_000C, 32'hAAAA_0003);

    // Read back
    request(1'b0, 32'h0000_0000, '0);
    check("boot line", resp_rdata,
          {32'hAAAA_0003, 32'hAAAA_0002, 32'hAAAA_0001, 32'hAAAA_0000});
    check_int("latency", waited, Latency);

    // Line write
    request(1'b1, 32'h0000_0010, {32'hBBBB_0003, 32'hBBBB_0002, 32'hBBBB_0001, 32'hBBBB_0000});
    request(1'b0, 32'h0000_0010, '0);
    check("line write", resp_rdata,
          {32'hBBBB_0003, 32'hBBBB_0002, 32'hBBBB_0001, 32'hBBBB_0000});

    // Untouched line
    request(1'b0, 32'h0000_0020, '0);
    check("untouched", resp_rdata, '0);

    // Word select
    request(1'b0, 32'h0000_0014, '0);
    check("word select", LineBits'(resp_rdata[63:32]), LineBits'(32'hBBBB_0001));

    verdict();
  end

endmodule
