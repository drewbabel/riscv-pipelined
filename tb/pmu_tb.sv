module pmu_tb;

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;

  logic [Xlen-1:0] addr;
  logic [Xlen-1:0] rdata;
  logic [Xlen-1:0] ic_hits;
  logic [Xlen-1:0] ic_misses;
  logic [Xlen-1:0] dc_hits;
  logic [Xlen-1:0] dc_misses;

  pmu #(
      .XLEN(Xlen)
  ) dut (
      .addr     (addr),
      .rdata    (rdata),
      .ic_hits  (ic_hits),
      .ic_misses(ic_misses),
      .dc_hits  (dc_hits),
      .dc_misses(dc_misses)
  );

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("%s: got %h exp %h", name, got, exp);
    end
  endtask

  task automatic read_check(input string name, input logic [Xlen-1:0] a,
                            input logic [Xlen-1:0] exp);
    addr = a;
    #1;
    check(name, rdata, exp);
  endtask

  initial begin
    $dumpfile("pmu_tb.vcd");
    $dumpvars(0, pmu_tb);

    ic_hits   = 32'h1111_1111;
    ic_misses = 32'h2222_2222;
    dc_hits   = 32'h3333_3333;
    dc_misses = 32'h4444_4444;

    read_check("ic_hits", 32'h0500_0000, 32'h1111_1111);
    read_check("ic_misses", 32'h0500_0004, 32'h2222_2222);
    read_check("dc_hits", 32'h0500_0008, 32'h3333_3333);
    read_check("dc_misses", 32'h0500_000C, 32'h4444_4444);

    read_check("byte_offset_ignored", 32'h0500_0001, 32'h1111_1111);
    read_check("upper_addr_ignored", 32'h0500_0104, 32'h2222_2222);

    ic_hits   = 32'hAAAA_AAAA;
    dc_misses = 32'hBBBB_BBBB;

    read_check("ic_hits_updated", 32'h0500_0000, 32'hAAAA_AAAA);
    read_check("dc_misses_updated", 32'h0500_000C, 32'hBBBB_BBBB);

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

endmodule
