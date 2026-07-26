module icache_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int Depth = 8192;
  localparam int Latency = 4;
  localparam int Stride = 1 << (IdxLsb + IcIdxLen);

  logic clk;
  logic core_en;
  logic rst_n;

  logic            cpu_valid;
  logic [Xlen-1:0] cpu_addr;
  logic [Xlen-1:0] cpu_rdata;
  logic            cpu_ready;

  logic                mem_valid;
  logic [    Xlen-1:0] mem_addr;
  logic [LineBits-1:0] mem_rdata;
  logic                mem_ready;

  logic [    Xlen-1:0] boot_addr;
  logic [    Xlen-1:0] boot_wdata;
  logic                boot_we;

  logic [        31:0] hit_count;
  logic [        31:0] miss_count;

  int checks = 0;
  int errors = 0;

  always #5 clk = ~clk;

  icache #(
      .XLEN(Xlen)
  ) dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .cpu_valid(cpu_valid),
      .cpu_addr(cpu_addr),
      .cpu_rdata(cpu_rdata),
      .cpu_ready(cpu_ready),
      .mem_valid(mem_valid),
      .mem_addr(mem_addr),
      .mem_rdata(mem_rdata),
      .mem_ready(mem_ready),
      .hit_count(hit_count),
      .miss_count(miss_count)
  );

  mem_delay #(
      .XLEN(Xlen),
      .DEPTH(Depth),
      .Latency(Latency)
  ) memory (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .req_valid(mem_valid),
      .req_rw(1'b0),
      .req_addr(mem_addr),
      .req_wdata('0),
      .resp_rdata(mem_rdata),
      .resp_ready(mem_ready),
      .boot_we(boot_we),
      .boot_addr(boot_addr),
      .boot_wdata(boot_wdata)
  );

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
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
    // Wait reset walk
    repeat (IcSets + 2) @(posedge clk);
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

  task automatic boot_line(input logic [Xlen-1:0] base, input logic [Xlen-1:0] seed);
    boot_word(base + 0, seed + 0);
    boot_word(base + 4, seed + 1);
    boot_word(base + 8, seed + 2);
    boot_word(base + 12, seed + 3);
  endtask  // Automatic

  task automatic fetch(input logic [Xlen-1:0] addr);
    int guard;
    #1;
    cpu_valid = 1'b1;
    cpu_addr  = addr;
    guard     = 0;
    @(posedge clk);
    while (!cpu_ready) begin
      guard++;
      if (guard > 200) $fatal(1, "cpu_ready never arrived for %h", addr);
      @(posedge clk);
    end
    #1;
    cpu_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, icache_tb);

    clk        = 1'b0;
    core_en    = 1'b1;
    rst_n      = 1'b1;
    cpu_valid  = 1'b0;
    cpu_addr   = '0;
    boot_we    = 1'b0;
    boot_addr  = '0;
    boot_wdata = '0;

    do_reset();

    boot_line(32'h0000_0000, 32'hA000_0000);
    boot_line(32'(Stride), 32'hB000_0000);
    boot_line(32'h0000_0010, 32'hC000_0000);

    // Cold miss
    fetch(32'h0000_0000);
    check("cold miss data", cpu_rdata, 32'hA000_0000);
    check_int("one miss", miss_count, 1);
    check_int("no hits yet", hit_count, 0);

    // Neighbour hits
    fetch(32'h0000_0004);
    check("neighbour 1", cpu_rdata, 32'hA000_0001);
    fetch(32'h0000_0008);
    check("neighbour 2", cpu_rdata, 32'hA000_0002);
    fetch(32'h0000_000C);
    check("neighbour 3", cpu_rdata, 32'hA000_0003);
    check_int("three hits", hit_count, 3);
    check_int("still one miss", miss_count, 1);

    // Other index
    fetch(32'h0000_0010);
    check("second index", cpu_rdata, 32'hC000_0000);
    fetch(32'h0000_0000);
    check("first index kept", cpu_rdata, 32'hA000_0000);
    check_int("two misses", miss_count, 2);

    // Conflict replaces
    fetch(32'(Stride));
    check("conflicting tag", cpu_rdata, 32'hB000_0000);
    fetch(32'h0000_0000);
    check("conflict evicted", cpu_rdata, 32'hA000_0000);
    check_int("conflict misses", miss_count, 4);

    verdict();
  end

endmodule
