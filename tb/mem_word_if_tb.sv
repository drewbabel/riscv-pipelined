module mem_word_if_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int MemLines = 64;

  logic                clk;
  logic                rst_n;
  logic                core_en;

  logic                i_cpu_valid;
  logic [    Xlen-1:0] i_cpu_addr;
  logic [    Xlen-1:0] i_cpu_rdata;
  logic                i_cpu_ready;
  logic                i_mem_valid;
  logic                i_mem_rw;
  logic [    Xlen-1:0] i_mem_addr;
  logic [LineBits-1:0] i_mem_wdata;
  logic [         3:0] i_mem_wstrb;
  logic [LineBits-1:0] i_mem_rdata;
  logic                i_mem_ready;
  logic [        31:0] i_hits;
  logic [        31:0] i_misses;

  logic                d_cpu_valid;
  logic                d_cpu_rw;
  logic [    Xlen-1:0] d_cpu_addr;
  logic [    Xlen-1:0] d_cpu_wdata;
  logic [         3:0] d_cpu_wstrb;
  logic [    Xlen-1:0] d_cpu_rdata;
  logic                d_cpu_ready;
  logic                d_mem_valid;
  logic                d_mem_rw;
  logic [    Xlen-1:0] d_mem_addr;
  logic [LineBits-1:0] d_mem_wdata;
  logic [         3:0] d_mem_wstrb;
  logic [LineBits-1:0] d_mem_rdata;
  logic                d_mem_ready;
  logic [        31:0] d_hits;
  logic [        31:0] d_misses;

  int                  checks = 0;
  int                  errors = 0;
  int                  max_lat = 6;
  int                  en_period = 1;
  int                  i_done = 0;
  int                  d_done = 0;

  always #5 clk = ~clk;

  mem_word_if #(
      .XLEN(Xlen),
      .RW  (1'b0)
  ) i_dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .cpu_valid(i_cpu_valid),
      .cpu_rw(1'b1),
      .cpu_addr(i_cpu_addr),
      .cpu_wdata(32'hDEAD_BEEF),
      .cpu_wstrb(4'hF),
      .cpu_rdata(i_cpu_rdata),
      .cpu_ready(i_cpu_ready),
      .mem_valid(i_mem_valid),
      .mem_rw(i_mem_rw),
      .mem_addr(i_mem_addr),
      .mem_wdata(i_mem_wdata),
      .mem_wstrb(i_mem_wstrb),
      .mem_rdata(i_mem_rdata),
      .mem_ready(i_mem_ready),
      .hit_count(i_hits),
      .miss_count(i_misses)
  );

  mem_word_if #(
      .XLEN(Xlen),
      .RW  (1'b1)
  ) d_dut (
      .clk(clk),
      .core_en(core_en),
      .rst_n(rst_n),
      .cpu_valid(d_cpu_valid),
      .cpu_rw(d_cpu_rw),
      .cpu_addr(d_cpu_addr),
      .cpu_wdata(d_cpu_wdata),
      .cpu_wstrb(d_cpu_wstrb),
      .cpu_rdata(d_cpu_rdata),
      .cpu_ready(d_cpu_ready),
      .mem_valid(d_mem_valid),
      .mem_rw(d_mem_rw),
      .mem_addr(d_mem_addr),
      .mem_wdata(d_mem_wdata),
      .mem_wstrb(d_mem_wstrb),
      .mem_rdata(d_mem_rdata),
      .mem_ready(d_mem_ready),
      .hit_count(d_hits),
      .miss_count(d_misses)
  );

  // Line memory model

  logic [LineBits-1:0] mem  [MemLines];

  function automatic int line_of(input logic [Xlen-1:0] a);
    line_of = (int'(a) >> 4) % MemLines;
  endfunction

  function automatic int word_of(input logic [Xlen-1:0] a);
    word_of = (int'(a) >> 2) % 4;
  endfunction

  task automatic fail(input string what);
    checks++;
    errors++;
    $error("t=%0t  %s", $time, what);
  endtask

  task automatic check(input string what, input logic [Xlen-1:0] got,
                       input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("t=%0t  %s: saw %h, memory holds %h", $time, what, got, exp);
      errors++;
    end
  endtask

  task automatic check_int(input string what, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      $error("t=%0t  %s: counted %0d, expected %0d", $time, what, got, exp);
      errors++;
    end
  endtask

  // Instruction responder
  logic                i_busy;
  logic                i_pend;
  int                  i_ctr;
  logic [LineBits-1:0] i_hold;

  always @(posedge clk) begin
    if (!rst_n) begin
      i_busy <= 1'b0;
      i_pend <= 1'b0;
      i_ctr  <= 0;
    end else begin
      if (!i_busy && !i_pend && i_mem_valid) begin
        i_busy <= 1'b1;
        i_ctr  <= $urandom_range(max_lat);
      end else if (i_busy) begin
        if (i_ctr == 0) begin
          i_busy <= 1'b0;
          i_pend <= 1'b1;
          i_hold <= mem[line_of(i_mem_addr)];
        end else begin
          i_ctr <= i_ctr - 1;
        end
      end
      if (i_pend && core_en) i_pend <= 1'b0;
    end
  end

  assign i_mem_ready = i_pend && core_en;
  assign i_mem_rdata = i_hold;

  // Data responder
  logic                d_busy;
  logic                d_pend;
  int                  d_ctr;
  logic [LineBits-1:0] d_hold;
  int                  b;

  always @(posedge clk) begin
    if (!rst_n) begin
      d_busy <= 1'b0;
      d_pend <= 1'b0;
      d_ctr  <= 0;
    end else begin
      if (!d_busy && !d_pend && d_mem_valid) begin
        d_busy <= 1'b1;
        d_ctr  <= $urandom_range(max_lat);
      end else if (d_busy) begin
        if (d_ctr == 0) begin
          d_busy <= 1'b0;
          d_pend <= 1'b1;
          if (d_mem_rw) begin
            for (b = 0; b < 4; b = b + 1) begin
              if (d_mem_wstrb[b])
                mem[line_of(d_mem_addr)][word_of(d_mem_addr)*32+b*8+:8] <= d_mem_wdata[b*8+:8];
            end
            d_hold <= '0;
          end else begin
            d_hold <= mem[line_of(d_mem_addr)];
          end
        end else begin
          d_ctr <= d_ctr - 1;
        end
      end
      if (d_pend && core_en) d_pend <= 1'b0;
    end
  end

  assign d_mem_ready = d_pend && core_en;
  assign d_mem_rdata = d_hold;

  // Protocol checks
  always @(posedge clk) begin
    if (rst_n) begin
      if (i_mem_rw) fail("read only instance drove a write command at memory");
      if (i_mem_wstrb != 4'h0) fail("read only instance drove a nonzero byte strobe");
      if (i_cpu_ready && !core_en) fail("instruction side asserted ready while core_en was low");
      if (d_cpu_ready && !core_en) fail("data side asserted ready while core_en was low");
      if (i_cpu_ready && !i_mem_ready) fail("instruction side answered without a memory response");
      if (d_cpu_ready && !d_mem_ready) fail("data side answered without a memory response");
    end
  end

  // Core enable
  int en_ctr = 0;
  always @(posedge clk) begin
    if (!rst_n) en_ctr <= 0;
    else en_ctr <= (en_ctr + 1) % en_period;
  end

  assign core_en = (en_ctr == 0);

  task automatic do_reset();
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask

  task automatic wait_i();
    int guard;
    bit seen;
    guard = 0;
    seen  = 1'b0;
    while (!seen) begin
      @(posedge clk);
      #1;
      if (i_cpu_ready) seen = 1'b1;
      guard++;
      if (guard > 4000) $fatal(1, "t=%0t  instruction access never completed", $time);
    end
  endtask

  task automatic wait_d();
    int guard;
    bit seen;
    guard = 0;
    seen  = 1'b0;
    while (!seen) begin
      @(posedge clk);
      #1;
      if (d_cpu_ready) seen = 1'b1;
      guard++;
      if (guard > 4000) $fatal(1, "t=%0t  data access never completed", $time);
    end
  endtask

  task automatic fetch(input logic [Xlen-1:0] addr, output logic [Xlen-1:0] data);
    #1;
    i_cpu_valid = 1'b1;
    i_cpu_addr  = addr;
    wait_i();
    data = i_cpu_rdata;
    i_cpu_valid = 1'b0;
    i_done++;
    @(posedge clk);
  endtask

  task automatic load(input logic [Xlen-1:0] addr, output logic [Xlen-1:0] data);
    #1;
    d_cpu_valid = 1'b1;
    d_cpu_rw    = 1'b0;
    d_cpu_addr  = addr;
    d_cpu_wstrb = 4'h0;
    wait_d();
    data = d_cpu_rdata;
    d_cpu_valid = 1'b0;
    d_done++;
    @(posedge clk);
  endtask

  task automatic store(input logic [Xlen-1:0] addr, input logic [3:0] strb,
                       input logic [Xlen-1:0] data);
    #1;
    d_cpu_valid = 1'b1;
    d_cpu_rw    = 1'b1;
    d_cpu_addr  = addr;
    d_cpu_wdata = data;
    d_cpu_wstrb = strb;
    wait_d();
    d_cpu_valid = 1'b0;
    d_cpu_wstrb = 4'h0;
    d_done++;
    @(posedge clk);
  endtask

  logic [Xlen-1:0] got;

  initial begin
    $dumpfile("mem_word_if_tb.vcd");
    $dumpvars(0, mem_word_if_tb);

    clk         = 1'b0;
    rst_n       = 1'b1;
    i_cpu_valid = 1'b0;
    i_cpu_addr  = '0;
    d_cpu_valid = 1'b0;
    d_cpu_rw    = 1'b0;
    d_cpu_addr  = '0;
    d_cpu_wdata = '0;
    d_cpu_wstrb = 4'h0;
    i_hold      = '0;
    d_hold      = '0;

    for (int i = 0; i < MemLines; i++) begin
      for (int w = 0; w < 4; w++) mem[i][w*32+:32] = 32'h1000_0000 + Xlen'(i * 4 + w);
    end

    do_reset();

    // Word select sweep
    for (int i = 0; i < MemLines; i++) begin
      for (int w = 0; w < 4; w++) begin
        logic [Xlen-1:0] a;
        a = Xlen'(i * 16 + w * 4);
        fetch(a, got);
        check($sformatf("instruction fetch selected the wrong word at %h", a), got,
              mem[i][w*32+:32]);
        load(a, got);
        check($sformatf("load selected the wrong word at %h", a), got, mem[i][w*32+:32]);
      end
    end

    // No line reuse
    for (int i = 0; i < 8; i++) begin
      fetch(32'h0000_0000, got);
      check("repeat fetch did not see the new memory contents", got, mem[0][31:0]);
      mem[0][31:0] = 32'hFACE_0000 + Xlen'(i);
      load(32'h0000_0004, got);
      check("repeat load did not see the new memory contents", got, mem[0][63:32]);
      mem[0][63:32] = 32'hCAFE_0000 + Xlen'(i);
    end

    // Store lane sweep
    for (int w = 0; w < 4; w++) begin
      logic [Xlen-1:0] a;
      a = 32'h0000_0100 + Xlen'(w * 4);
      store(a, 4'hF, 32'h2222_0000 + Xlen'(w));
      fetch(a, got);
      check($sformatf("store did not land in word %0d of the line", w), got,
            32'h2222_0000 + Xlen'(w));
      fetch(32'h0000_0100 + Xlen'(((w + 1) % 4) * 4), got);
      check($sformatf("store from word %0d overwrote a neighbouring word", w), got,
            mem[16][((w+1)%4)*32+:32]);
    end

    // Byte strobe sweep
    begin
      logic [3:0] strobes[4];
      logic [Xlen-1:0] want;
      strobes[0] = 4'b0001;
      strobes[1] = 4'b1100;
      strobes[2] = 4'b0110;
      strobes[3] = 4'b1111;
      for (int s = 0; s < 4; s++) begin
        store(32'h0000_0200, 4'hF, 32'h3333_3333);
        want = 32'h3333_3333;
        for (int i = 0; i < 4; i++) begin
          if (strobes[s][i]) want[i*8+:8] = 8'h70 + 8'(i);
        end
        store(32'h0000_0200, strobes[s], {8'h73, 8'h72, 8'h71, 8'h70});
        load(32'h0000_0200, got);
        check($sformatf("store ignored byte strobe %04b", strobes[s]), got, want);
      end
    end

    // Core enable sweep
    begin
      int periods[5];
      periods[0] = 1;
      periods[1] = 2;
      periods[2] = 3;
      periods[3] = 5;
      periods[4] = 8;
      for (int p = 0; p < 5; p++) begin
        en_period = periods[p];
        max_lat   = (p % 3) * 5;
        @(posedge clk);
        for (int i = 0; i < 6; i++) begin
          logic [Xlen-1:0] a;
          a = 32'h0000_0300 + Xlen'(i * 4);
          store(a, 4'hF, 32'h4444_0000 + Xlen'(p * 16 + i));
          fetch(a, got);
          check($sformatf("store did not reach memory, core_en 1 cycle in %0d", en_period),
                got, 32'h4444_0000 + Xlen'(p * 16 + i));
        end
      end
      en_period = 1;
      max_lat   = 6;
    end

    // Random traffic
    for (int i = 0; i < 200; i++) begin
      logic [Xlen-1:0] a;
      logic [Xlen-1:0] d;
      logic [3:0] strb;
      a    = Xlen'($urandom_range(MemLines * 4 - 1) * 4);
      d    = $urandom();
      strb = 4'($urandom_range(15));
      if ($urandom_range(1) == 0) begin
        fetch(a, got);
        check("random fetch returned the wrong word", got,
              mem[line_of(a)][word_of(a)*32+:32]);
      end else begin
        if (strb != 4'h0) store(a, strb, d);
        load(a, got);
        check("random load returned the wrong word", got, mem[line_of(a)][word_of(a)*32+:32]);
      end
    end

    #1;
    check_int("instruction side reported hits", int'(i_hits), 0);
    check_int("data side reported hits", int'(d_hits), 0);
    check_int("instruction side missed on a different number of accesses", int'(i_misses),
              i_done);
    check_int("data side missed on a different number of accesses", int'(d_misses), d_done);

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

  initial begin
    #4000000;
    $fatal(1, "global time limit reached before the stimulus finished");
  end

endmodule
