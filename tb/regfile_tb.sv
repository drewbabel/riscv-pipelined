module regfile_tb ();

  localparam int AWIDTH = 5;
  localparam int XLEN = 32;
  localparam int Depth = 2 ** AWIDTH;

  int checks = 0;
  int errors = 0;

  logic clk = 1'b0;
  logic rst_n = 1'b1;
  logic we;
  logic [AWIDTH-1:0] waddr;
  logic [XLEN-1:0] wdata;
  logic [AWIDTH-1:0] raddr1;
  logic [AWIDTH-1:0] raddr2;
  logic [XLEN-1:0] rdata1;
  logic [XLEN-1:0] rdata2;

  logic [XLEN-1:0] shadow[Depth];

  always #5 clk = ~clk;

  regfile #(
      .AWIDTH(AWIDTH),
      .XLEN  (XLEN)
  ) dut (
      .clk(clk),
      .core_en(1'b1),
      .rst_n(rst_n),
      .we(we),
      .waddr(waddr),
      .wdata(wdata),
      .raddr1(raddr1),
      .raddr2(raddr2),
      .rdata1(rdata1),
      .rdata2(rdata2)
  );

  // Stimulus
  task automatic do_reset();
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask

  task automatic write_reg(input logic [AWIDTH-1:0] addr, input logic [XLEN-1:0] data);
    #1;
    waddr = addr;
    wdata = data;
    we = 1'b1;
    @(posedge clk);
    @(negedge clk);
    we = 1'b0;
  endtask

  task automatic check_read(input logic [AWIDTH-1:0] addr, input logic [XLEN-1:0] got);
    logic [XLEN-1:0] exp;
    exp = (addr == 0) ? '0 : shadow[addr];
    checks++;
    if (got !== exp) begin
      errors++;
      $display("Read mismatch addr=%0d exp=%h got=%h", addr, exp, got);
    end
  endtask

  task automatic check_reads(input logic [AWIDTH-1:0] addr1, input logic [AWIDTH-1:0] addr2);
    #1;
    raddr1 = addr1;
    raddr2 = addr2;
    #1;  // Let combinational read ports settle before sampling
    check_read(raddr1, rdata1);
    check_read(raddr2, rdata2);
  endtask

  task automatic verdict();
    @(posedge clk);
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  // Reference model
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int i = 0; i < Depth; i++) shadow[i] <= '0;
    end else if (we && waddr != 0) begin
      shadow[waddr] <= wdata;
    end
  end

  initial begin
    $dumpfile("regfile_tb.vcd");
    $dumpvars(0, regfile_tb);
    do_reset();

    // Write then read same register on both ports
    write_reg(5, 32'hDEAD_BEEF);
    check_reads(5, 5);

    // Write to x0, then read x0: must stay zero
    write_reg(0, 32'hFFFF_FFFF);
    check_reads(0, 0);

    // Two different registers, read simultaneously
    write_reg(7, 32'h0000_00AA);
    write_reg(9, 32'h0000_00BB);
    check_reads(7, 9);

    // Reset mid-stream
    do_reset();
    check_reads(5, 9);

    // Randomized sweep
    for (int i = 0; i < 1000; i++) begin
      write_reg(AWIDTH'($urandom), XLEN'($urandom));
      check_reads(AWIDTH'($urandom), AWIDTH'($urandom));
    end

    verdict();
  end

endmodule
