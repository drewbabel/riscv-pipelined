module mem_tb ();

  int checks = 0;
  int errors = 0;

  localparam int XLEN = 32;
  localparam int DEPTH = 8192;
  localparam int AddrWidth = $clog2(DEPTH);

  logic            clk = 1'b0;
  logic [XLEN-1:0] iaddr;
  logic [XLEN-1:0] instr;
  logic [     3:0] wstrb;
  logic [XLEN-1:0] daddr;
  logic [XLEN-1:0] wdata;
  logic [XLEN-1:0] rdata;

  always #5 clk = ~clk;

  mem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) dut (
      .clk(clk),
      .core_en(1'b1),
      .iaddr(iaddr),
      .instr(instr),
      .wstrb(wstrb),
      .daddr(daddr),
      .wdata(wdata),
      .rdata(rdata)
  );

  task automatic check(input string name, input logic [XLEN-1:0] got, input logic [XLEN-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s got %08x exp %08x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic verdict();
    @(posedge clk);
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  task automatic check_a(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] exp_data);
    #1;
    iaddr = addr;
    @(negedge clk);
    #1;
    check("Port A", instr, exp_data);
  endtask  // Automatic

  task automatic check_b(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] data);
    // Write
    #1;
    wdata = data;
    daddr = addr;
    wstrb = 4'hF;
    @(negedge clk);
    #1;
    wstrb = '0;
    check("Port B", rdata, data);
  endtask  // Automatic

  task automatic write_word(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] data);
    #1;
    daddr = addr;
    wdata = data;
    wstrb = 4'hF;
    @(negedge clk);
    #1;
    wstrb = '0;
  endtask  // Automatic

  task automatic write_byte_lane(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] data,
                                 input logic [3:0] mask);
    #1;
    daddr = addr;
    wdata = data;
    wstrb = mask;
    @(negedge clk);
    #1;
    wstrb = '0;
  endtask  // Automatic

  task automatic check_b_readback(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] data);
    #1;
    daddr = addr;
    wdata = data;
    wstrb = 4'hF;
    @(negedge clk);
    #1;
    wstrb = '0;
    @(negedge clk);
    #1;
    check("Port B readback", rdata, data);
  endtask  // Automatic

  task automatic check_a_shared(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] exp_data);
    #1;
    iaddr = addr;
    @(negedge clk);
    #1;
    check("Port A shared", instr, exp_data);
  endtask  // Automatic

  task automatic check_mem(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] exp_data);
    #1;
    check("Memory", {
          dut.g_lane[3].bmem[addr[AddrWidth+1:2]],
          dut.g_lane[2].bmem[addr[AddrWidth+1:2]],
          dut.g_lane[1].bmem[addr[AddrWidth+1:2]],
          dut.g_lane[0].bmem[addr[AddrWidth+1:2]]
          }, exp_data);
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, mem_tb);

    iaddr = '0;
    daddr = '0;
    wdata = '0;
    wstrb = '0;

    // Byte-lane write
    write_word(32'h0000_0010, 32'h1122_3344);
    write_word(32'h0000_0020, 32'hAABB_CCDD);
    check_mem(32'h0000_0010, 32'h1122_3344);
    check_mem(32'h0000_0020, 32'hAABB_CCDD);

    write_byte_lane(32'h0000_0010, 32'h0000_EE00, 4'b0010);
    check_mem(32'h0000_0010, 32'h1122_EE44);
    check_mem(32'h0000_0020, 32'hAABB_CCDD);

    write_byte_lane(32'h0000_0020, 32'h0000_9900, 4'b0010);
    check_mem(32'h0000_0020, 32'hAABB_99DD);
    check_mem(32'h0000_0010, 32'h1122_EE44);

    // Show both ports share one array
    check_b_readback(32'h0000_0030, 32'hCAFE_BABE);
    check_a_shared(32'h0000_0030, 32'hCAFE_BABE);

    verdict();
  end

endmodule
