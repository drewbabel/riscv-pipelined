module dcache_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int Depth = 8192;
  localparam int Latency = 4;
  localparam int Stride = 1 << (IdxLsb + DcIdxLen);

  logic clk;
  logic core_en;
  logic rst_n;

  logic            cpu_valid;
  logic            cpu_rw;
  logic [Xlen-1:0] cpu_addr;
  logic [Xlen-1:0] cpu_wdata;
  logic [     3:0] cpu_wstrb;
  logic [Xlen-1:0] cpu_rdata;
  logic            cpu_ready;

  logic                mem_valid;
  logic                mem_rw;
  logic [    Xlen-1:0] mem_addr;
  logic [LineBits-1:0] mem_wdata;
  logic [LineBits-1:0] mem_rdata;
  logic                mem_ready;

  logic [Xlen-1:0] boot_addr;
  logic [Xlen-1:0] boot_wdata;
  logic            boot_we;

  logic [    31:0] hit_count;
  logic [    31:0] miss_count;

  int checks = 0;
  int errors = 0;
  int writebacks = 0;
  int wb_mark = 0;

  always #5 clk = ~clk;

  dcache #(
      .XLEN(Xlen)
  ) dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .cpu_valid(cpu_valid),
      .cpu_rw(cpu_rw),
      .cpu_addr(cpu_addr),
      .cpu_wdata(cpu_wdata),
      .cpu_wstrb(cpu_wstrb),
      .cpu_rdata(cpu_rdata),
      .cpu_ready(cpu_ready),
      .mem_valid(mem_valid),
      .mem_rw(mem_rw),
      .mem_addr(mem_addr),
      .mem_wdata(mem_wdata),
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
      .req_rw(mem_rw),
      .req_addr(mem_addr),
      .req_wdata(mem_wdata),
      .resp_rdata(mem_rdata),
      .resp_ready(mem_ready),
      .boot_we(boot_we),
      .boot_addr(boot_addr),
      .boot_wdata(boot_wdata)
  );

  // Count write backs
  always @(posedge clk) begin
    if (rst_n && mem_ready && memory.req_rw_q) writebacks++;
  end

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
    repeat (DcSets + 2) @(posedge clk);
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

  task automatic access(input logic rw, input logic [Xlen-1:0] addr, input logic [3:0] strb,
                        input logic [Xlen-1:0] data);
    int guard;
    #1;
    cpu_valid = 1'b1;
    cpu_rw    = rw;
    cpu_addr  = addr;
    cpu_wstrb = strb;
    cpu_wdata = data;
    guard     = 0;
    @(posedge clk);
    while (!cpu_ready) begin
      guard++;
      if (guard > 200) $fatal(1, "cpu_ready never arrived for %h", addr);
      @(posedge clk);
    end
    #1;
    cpu_valid = 1'b0;
    cpu_wstrb = 4'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic read(input logic [Xlen-1:0] addr);
    access(1'b0, addr, 4'b0, '0);
  endtask  // Automatic

  task automatic write(input logic [Xlen-1:0] addr, input logic [Xlen-1:0] data);
    access(1'b1, addr, 4'hF, data);
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, dcache_tb);

    clk        = 1'b0;
    core_en    = 1'b1;
    rst_n      = 1'b1;
    cpu_valid  = 1'b0;
    cpu_rw     = 1'b0;
    cpu_addr   = '0;
    cpu_wdata  = '0;
    cpu_wstrb  = '0;
    boot_we    = 1'b0;
    boot_addr  = '0;
    boot_wdata = '0;

    do_reset();

    // Index zero lines
    boot_line(32'h0000_0000, 32'hA000_0000);
    boot_line(32'(Stride), 32'hB000_0000);
    boot_line(32'(2*Stride), 32'hC000_0000);
    boot_line(32'(3*Stride), 32'h1000_0000);
    boot_line(32'(4*Stride), 32'h2000_0000);

    // Index one lines
    boot_line(32'h0000_0010, 32'hD000_0000);
    boot_line(32'(Stride + 16), 32'hE000_0000);
    boot_line(32'(2*Stride + 16), 32'hF000_0000);
    boot_line(32'(3*Stride + 16), 32'h3000_0000);
    boot_line(32'(4*Stride + 16), 32'h4000_0000);

    // Cold miss
    read(32'h0000_0000);
    check("cold miss data", cpu_rdata, 32'hA000_0000);
    check_int("miss after cold", miss_count, 1);

    read(32'h0000_0004);
    check("neighbour 1", cpu_rdata, 32'hA000_0001);
    read(32'h0000_0008);
    check("neighbour 2", cpu_rdata, 32'hA000_0002);
    read(32'h0000_000C);
    check("neighbour 3", cpu_rdata, 32'hA000_0003);
    check_int("hits after line", hit_count, 3);
    check_int("miss still one", miss_count, 1);

    // Store hit
    write(32'h0000_0004, 32'hDEAD_BEEF);
    read(32'h0000_0004);
    check("store hit", cpu_rdata, 32'hDEAD_BEEF);

    // Fill remaining ways
    read(32'(Stride));
    check("second way", cpu_rdata, 32'hB000_0000);
    read(32'(2*Stride));
    check("third way", cpu_rdata, 32'hC000_0000);
    read(32'(3*Stride));
    check("fourth way", cpu_rdata, 32'h1000_0000);

    // Oldest touch first
    read(32'h0000_0000);
    check("way A kept", cpu_rdata, 32'hA000_0000);
    read(32'(Stride));
    check("way B kept", cpu_rdata, 32'hB000_0000);
    read(32'(2*Stride));
    check("way C kept", cpu_rdata, 32'hC000_0000);
    read(32'(3*Stride));
    check("way G kept", cpu_rdata, 32'h1000_0000);

    // Fifth tag evicts
    wb_mark = writebacks;
    read(32'(4*Stride));
    check("fifth tag", cpu_rdata, 32'h2000_0000);
    check_int("dirty evict wrote back", writebacks - wb_mark, 1);

    // Write back landed
    read(32'h0000_0004);
    check("write back landed", cpu_rdata, 32'hDEAD_BEEF);

    // Clean evict silent
    do_reset();
    wb_mark = writebacks;
    read(32'h0000_0010);
    check("index 1 way 0", cpu_rdata, 32'hD000_0000);
    read(32'(Stride + 16));
    check("index 1 way 1", cpu_rdata, 32'hE000_0000);
    read(32'(2*Stride + 16));
    check("index 1 way 2", cpu_rdata, 32'hF000_0000);
    read(32'(3*Stride + 16));
    check("index 1 way 3", cpu_rdata, 32'h3000_0000);
    read(32'(4*Stride + 16));
    check("index 1 evict", cpu_rdata, 32'h4000_0000);
    check_int("clean evict silent", writebacks - wb_mark, 0);

    verdict();
  end

endmodule
