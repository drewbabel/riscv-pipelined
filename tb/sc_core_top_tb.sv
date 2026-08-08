module sc_core_top_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int MemLines = 256;
  localparam int ProgWords = 17;
  localparam int MaxTicks = 20000;
  localparam logic [7:0] PeriphTag = 8'h03;

  int checks = 0;
  int errors = 0;
  int max_lat = 3;
  int en_period = 2;

  logic                clk = 1'b0;
  logic                rst_n;
  logic                core_en;

  logic [    Xlen-1:0] instr;
  logic [    Xlen-1:0] read_data;
  logic [    Xlen-1:0] pc;
  logic [    Xlen-1:0] mem_addr;
  logic [         3:0] store_wstrb;
  logic [    Xlen-1:0] store_data;
  logic                imem_req;
  logic                imem_ready;
  logic                dmem_req;
  logic                dmem_ready;
  logic                periph_sel;
  logic                irq_stim = 1'b0;

  logic [    Xlen-1:0] dc_rdata;
  logic                dc_ready;

  logic                ic_mem_valid;
  logic [    Xlen-1:0] ic_mem_addr;
  logic [LineBits-1:0] ic_mem_rdata;
  logic                ic_mem_ready;

  logic                dc_mem_valid;
  logic                dc_mem_rw;
  logic [    Xlen-1:0] dc_mem_addr;
  logic [LineBits-1:0] dc_mem_wdata;
  logic [         3:0] dc_mem_wstrb;
  logic [LineBits-1:0] dc_mem_rdata;
  logic                dc_mem_ready;

  logic [        31:0] ic_hits;
  logic [        31:0] ic_misses;
  logic [        31:0] dc_hits;
  logic [        31:0] dc_misses;

  always #5 clk = ~clk;

  sc_core_top #(
      .XLEN(Xlen)
  ) dut (
      .clk        (clk),
      .core_en    (core_en),
      .rst_n      (rst_n),
      .instr      (instr),
      .read_data  (read_data),
      .timer_irq  (irq_stim),
      .imem_ready (imem_ready),
      .dmem_ready (dmem_ready),
      .imem_req   (imem_req),
      .dmem_req   (dmem_req),
      .pc         (pc),
      .mem_write  (),
      .alu_result (),
      .write_data (),
      .store_wstrb(store_wstrb),
      .store_data (store_data),
      .mem_addr   (mem_addr)
  );

  mem_word_if #(
      .XLEN(Xlen),
      .RW  (1'b0)
  ) icache_inst (
      .clk       (clk),
      .core_en   (core_en),
      .rst_n     (rst_n),
      .cpu_valid (imem_req),
      .cpu_rw    (1'b0),
      .cpu_addr  (pc),
      .cpu_wdata ('0),
      .cpu_wstrb ('0),
      .cpu_rdata (instr),
      .cpu_ready (imem_ready),
      .mem_valid (ic_mem_valid),
      .mem_rw    (),
      .mem_addr  (ic_mem_addr),
      .mem_wdata (),
      .mem_wstrb (),
      .mem_rdata (ic_mem_rdata),
      .mem_ready (ic_mem_ready),
      .hit_count (ic_hits),
      .miss_count(ic_misses)
  );

  mem_word_if #(
      .XLEN(Xlen),
      .RW  (1'b1)
  ) dcache_inst (
      .clk       (clk),
      .core_en   (core_en),
      .rst_n     (rst_n),
      .cpu_valid (dmem_req && !periph_sel),
      .cpu_rw    (|store_wstrb),
      .cpu_addr  (mem_addr),
      .cpu_wdata (store_data),
      .cpu_wstrb (store_wstrb),
      .cpu_rdata (dc_rdata),
      .cpu_ready (dc_ready),
      .mem_valid (dc_mem_valid),
      .mem_rw    (dc_mem_rw),
      .mem_addr  (dc_mem_addr),
      .mem_wdata (dc_mem_wdata),
      .mem_wstrb (dc_mem_wstrb),
      .mem_rdata (dc_mem_rdata),
      .mem_ready (dc_mem_ready),
      .hit_count (dc_hits),
      .miss_count(dc_misses)
  );

  // Peripheral stand in
  logic [Xlen-1:0] periph_reg;
  int              periph_writes = 0;

  // Board decode
  assign periph_sel = mem_addr[31:24] == PeriphTag;
  assign dmem_ready = periph_sel ? 1'b1 : dc_ready;
  assign read_data  = periph_sel ? periph_reg : dc_rdata;

  always @(posedge clk) begin
    if (!rst_n) begin
      periph_reg    <= '0;
      periph_writes <= 0;
    end else if (core_en && periph_sel && |store_wstrb) begin
      periph_reg    <= store_data;
      periph_writes <= periph_writes + 1;
    end
  end

  // Line memory model
  logic [LineBits-1:0] mem[MemLines];
  logic [    Xlen-1:0] img[ProgWords];

  function automatic int line_of(input logic [Xlen-1:0] a);
    line_of = (int'(a) >> 4) % MemLines;
  endfunction  // Automatic

  function automatic int word_of(input logic [Xlen-1:0] a);
    word_of = (int'(a) >> 2) % LineWords;
  endfunction  // Automatic

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
      if (!i_busy && !i_pend && ic_mem_valid) begin
        i_busy <= 1'b1;
        i_ctr  <= $urandom_range(max_lat);
      end else if (i_busy) begin
        if (i_ctr == 0) begin
          i_busy <= 1'b0;
          i_pend <= 1'b1;
          i_hold <= mem[line_of(ic_mem_addr)];
        end else begin
          i_ctr <= i_ctr - 1;
        end
      end
      if (i_pend && core_en) i_pend <= 1'b0;
    end
  end

  // Valid on ready
  assign ic_mem_ready = i_pend && core_en;
  assign ic_mem_rdata = ic_mem_ready ? i_hold : '1;

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
      if (!d_busy && !d_pend && dc_mem_valid) begin
        d_busy <= 1'b1;
        d_ctr  <= $urandom_range(max_lat);
      end else if (d_busy) begin
        if (d_ctr == 0) begin
          d_busy <= 1'b0;
          d_pend <= 1'b1;
          if (dc_mem_rw) begin
            for (b = 0; b < 4; b = b + 1) begin
              if (dc_mem_wstrb[b])
                mem[line_of(dc_mem_addr)][word_of(dc_mem_addr)*32+b*8+:8] <= dc_mem_wdata[b*8+:8];
            end
            d_hold <= '0;
          end else begin
            d_hold <= mem[line_of(dc_mem_addr)];
          end
        end else begin
          d_ctr <= d_ctr - 1;
        end
      end
      if (d_pend && core_en) d_pend <= 1'b0;
    end
  end

  // Valid on ready
  assign dc_mem_ready = d_pend && core_en;
  assign dc_mem_rdata = dc_mem_ready ? d_hold : '1;

  // Core enable
  int en_ctr = 0;
  always @(posedge clk) begin
    if (!rst_n) en_ctr <= 0;
    else en_ctr <= (en_ctr + 1) % en_period;
  end

  assign core_en = (en_ctr == 0);

  task automatic fail(input string what);
    checks++;
    errors++;
    $error("t=%0t  %s", $time, what);
  endtask  // Automatic

  // Freeze checks
  logic [Xlen-1:0] instr_h_q;
  logic [Xlen-1:0] rdata_h_q;
  logic            core_en_q;
  logic            irq_h_q;

  always @(posedge clk) begin
    instr_h_q <= dut.instr_h;
    rdata_h_q <= dut.rdata_h;
    core_en_q <= core_en;
    irq_h_q   <= dut.irq_h;
    irq_stim  <= ~irq_stim;
    if (rst_n) begin
      if (dut.core_step && (dut.instr_cap || dut.data_cap))
        fail("core stepped on a hold capture cycle");
      if (dut.core_step && !core_en) fail("core stepped while core_en was low");
      if (dut.instr_cap && !core_en) fail("instruction hold captured while core_en was low");
      if (dut.data_cap && !core_en) fail("data hold captured while core_en was low");
      if ((dut.instr_h !== instr_h_q) && !core_en_q)
        fail("instruction hold moved outside a core_en cycle");
      if ((dut.rdata_h !== rdata_h_q) && !core_en_q)
        fail("data hold moved outside a core_en cycle");
      if ((dut.irq_h !== irq_h_q) && !core_en_q)
        fail("interrupt hold moved outside a core_en cycle");
      if (|store_wstrb && !dmem_req) fail("byte strobe live outside the request cycle");
      if (imem_req && dmem_req) fail("fetch and data request overlapped");
    end
  end

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s = 0x%08h, expected 0x%08h", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  function automatic logic [Xlen-1:0] reg_of(input int n);
    reg_of = dut.riscv_single_inst.datapath_inst.regfile_inst.regfile_mem[n];
  endfunction  // Automatic

  int ticks = 0;

  initial begin
    $dumpfile("sc_core_top_tb.vcd");
    $dumpvars(0, sc_core_top_tb);

    for (int i = 0; i < MemLines; i++) mem[i] = '0;
    $readmemh("tests/sc_smoke.hex", img);
    if ($isunknown(img[0]) || img[0] == 32'h0)
      $fatal(1, "sc_smoke.hex missing or empty, run make hex PROG=sc_smoke");
    for (int i = 0; i < ProgWords; i++) mem[i/LineWords][(i%LineWords)*32+:32] = img[i];

    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    while (reg_of(28) !== 32'd1 && ticks < MaxTicks) begin
      @(posedge clk);
      ticks++;
    end
    if (ticks >= MaxTicks) $fatal(1, "t=%0t  core never reached the done flag", $time);

    repeat (4) @(posedge clk);

    check("x1 immediate", reg_of(1), 32'h0000_ABCD);
    check("x3 word load", reg_of(3), 32'h0000_ABCD);
    check("x7 byte load", reg_of(7), 32'h0000_00CD);
    check("x8 halfword load", reg_of(8), 32'hFFFF_ABCD);
    check("x11 peripheral read", reg_of(11), 32'h0000_ABCD);
    check("x28 done flag", reg_of(28), 32'd1);

    // Single strobe
    checks++;
    if (periph_writes != 1) begin
      $error("peripheral saw %0d write strobes, expected 1", periph_writes);
      errors++;
    end

    // Free running mcycle
    checks++;
    if (reg_of(10) <= 32'd13) begin
      $error("mcycle advanced %0d, no more than the instructions retired", reg_of(10));
      errors++;
    end

    checks++;
    if (mem[64][31:0] !== 32'h0000_ABCD) begin
      $error("store did not reach memory, line holds 0x%08h", mem[64][31:0]);
      errors++;
    end

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "global time limit reached before the stimulus finished");
  end

endmodule
