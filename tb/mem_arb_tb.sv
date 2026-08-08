module mem_arb_tb;

  import cache_pkg::*;

  localparam int Xlen = 32;
  localparam int AppAddrW = 29;
  localparam int MaskW = LineBits / 8;
  localparam int MemLines = 1024;
  localparam int QDepth = 8;
  localparam int RdLat = 12;

  localparam logic [2:0] AppWrite = 3'b000;
  localparam logic [2:0] AppRead = 3'b001;

  logic                clk;
  logic                rst_n;
  logic                core_en;
  logic                calib_done;

  logic                ic_req_valid;
  logic [    Xlen-1:0] ic_req_addr;
  logic [LineBits-1:0] ic_resp_rdata;
  logic                ic_resp_ready;

  logic                dc_req_valid;
  logic                dc_req_rw;
  logic [    Xlen-1:0] dc_req_addr;
  logic [LineBits-1:0] dc_req_wdata;
  logic [         3:0] dc_req_wstrb;
  logic [LineBits-1:0] dc_resp_rdata;
  logic                dc_resp_ready;

  logic                boot_we;
  logic [    Xlen-1:0] boot_addr;
  logic [    Xlen-1:0] boot_wdata;

  logic [AppAddrW-1:0] app_addr;
  logic [         2:0] app_cmd;
  logic                app_en;
  logic                app_rdy;

  logic [LineBits-1:0] app_wdf_data;
  logic [   MaskW-1:0] app_wdf_mask;
  logic                app_wdf_wren;
  logic                app_wdf_end;
  logic                app_wdf_rdy;

  logic [LineBits-1:0] app_rd_data;
  logic                app_rd_data_valid;

  int                  checks = 0;
  int                  errors = 0;
  int                  rd_lat = RdLat;
  int                  rdy_pct = 100;
  int                  wdf_pct = 100;
  int                  en_period = 1;

  always #5 clk = ~clk;

  mem_arb #(
      .XLEN(Xlen),
      .APP_ADDR_WIDTH(AppAddrW)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .core_en(core_en),
      .calib_done(calib_done),
      .ic_req_valid(ic_req_valid),
      .ic_req_addr(ic_req_addr),
      .ic_resp_rdata(ic_resp_rdata),
      .ic_resp_ready(ic_resp_ready),
      .dc_req_valid(dc_req_valid),
      .dc_req_rw(dc_req_rw),
      .dc_req_addr(dc_req_addr),
      .dc_req_wdata(dc_req_wdata),
      .dc_req_wstrb(dc_req_wstrb),
      .dc_resp_rdata(dc_resp_rdata),
      .dc_resp_ready(dc_resp_ready),
      .boot_we(boot_we),
      .boot_addr(boot_addr),
      .boot_wdata(boot_wdata),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_rdy(app_rdy),
      .app_wdf_data(app_wdf_data),
      .app_wdf_mask(app_wdf_mask),
      .app_wdf_wren(app_wdf_wren),
      .app_wdf_end(app_wdf_end),
      .app_wdf_rdy(app_wdf_rdy),
      .app_rd_data(app_rd_data),
      .app_rd_data_valid(app_rd_data_valid)
  );

  // Controller model

  logic [LineBits-1:0] mem       [MemLines];

  logic [         2:0] cq_cmd    [  QDepth];
  logic [AppAddrW-1:0] cq_addr   [  QDepth];
  int                  cq_wr = 0;
  int                  cq_rd = 0;

  logic [LineBits-1:0] wq_data   [  QDepth];
  logic [   MaskW-1:0] wq_mask   [  QDepth];
  int                  wq_wr = 0;
  int                  wq_rd = 0;

  logic [     RdLat:0] rd_v;
  logic [LineBits-1:0] rd_d      [ RdLat+1];

  logic                cmd_accept;
  logic                wdf_accept;
  logic                cq_head_live;
  logic                wq_head_live;
  int                  cq_wr_eff;
  int                  wq_wr_eff;
  logic [         2:0] head_cmd;
  logic [AppAddrW-1:0] head_addr;
  logic [LineBits-1:0] head_data;
  logic [   MaskW-1:0] head_mask;

  assign cmd_accept   = app_en && app_rdy;
  assign wdf_accept   = app_wdf_wren && app_wdf_rdy;
  assign cq_head_live = (cq_rd == cq_wr) && cmd_accept;
  assign wq_head_live = (wq_rd == wq_wr) && wdf_accept;
  assign cq_wr_eff    = cq_wr + (cmd_accept ? 1 : 0);
  assign wq_wr_eff    = wq_wr + (wdf_accept ? 1 : 0);
  assign head_cmd     = cq_head_live ? app_cmd : cq_cmd[cq_rd%QDepth];
  assign head_addr    = cq_head_live ? app_addr : cq_addr[cq_rd%QDepth];
  assign head_data    = wq_head_live ? app_wdf_data : wq_data[wq_rd%QDepth];
  assign head_mask    = wq_head_live ? app_wdf_mask : wq_mask[wq_rd%QDepth];

  function automatic int line_of(input logic [AppAddrW-1:0] a);
    line_of = (int'(a) >> 4) % MemLines;
  endfunction  // Automatic

  task automatic fail(input string what);
    checks++;
    errors++;
    $error("t=%0t  %s", $time, what);
  endtask  // Automatic

  task automatic check(input string what, input logic [LineBits-1:0] got,
                       input logic [LineBits-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("t=%0t  %s: read back %h, memory holds %h", $time, what, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic check_int(input string what, input int got, input int exp);
    checks++;
    if (got !== exp) begin
      $error("t=%0t  %s: counted %0d, expected %0d", $time, what, got, exp);
      errors++;
    end
  endtask  // Automatic

  // Ready generators
  always @(posedge clk) begin
    if (!calib_done) begin
      app_rdy     <= 1'b0;
      app_wdf_rdy <= 1'b0;
    end else begin
      app_rdy     <= ($urandom_range(99) < rdy_pct);
      app_wdf_rdy <= ($urandom_range(99) < wdf_pct);
    end
  end

  // Queues and memory
  integer b;
  integer k;
  always @(posedge clk) begin
    if (!rst_n) begin
      cq_wr <= 0;
      cq_rd <= 0;
      wq_wr <= 0;
      wq_rd <= 0;
      rd_v  <= '0;
    end else begin
      if (cmd_accept) begin
        if (cq_wr - cq_rd >= QDepth)
          fail("command issued with 8 already unretired at the controller");
        cq_cmd[cq_wr%QDepth]  <= app_cmd;
        cq_addr[cq_wr%QDepth] <= app_addr;
        cq_wr                 <= cq_wr + 1;
      end

      if (wdf_accept) begin
        if (wq_wr - wq_rd >= QDepth)
          fail("write beat issued with 8 already unretired at the controller");
        if (!app_wdf_end) fail("wdf_end low on an accepted write data beat");
        wq_data[wq_wr%QDepth] <= app_wdf_data;
        wq_mask[wq_wr%QDepth] <= app_wdf_mask;
        wq_wr                 <= wq_wr + 1;
      end

      rd_v <= rd_v >> 1;
      for (k = 0; k < RdLat; k = k + 1) rd_d[k] <= rd_d[k+1];

      // Service head
      if (cq_rd < cq_wr_eff) begin
        if (head_cmd == AppRead) begin
          rd_v[rd_lat] <= 1'b1;
          rd_d[rd_lat] <= mem[line_of(head_addr)];
          cq_rd        <= cq_rd + 1;
        end else if (wq_rd < wq_wr_eff) begin
          for (b = 0; b < MaskW; b = b + 1) begin
            if (!head_mask[b]) mem[line_of(head_addr)][8*b+:8] <= head_data[8*b+:8];
          end
          cq_rd <= cq_rd + 1;
          wq_rd <= wq_rd + 1;
        end
      end
    end
  end

  assign app_rd_data_valid = rd_v[0];
  assign app_rd_data = rd_d[0];

  // Protocol checks
  always @(posedge clk) begin
    if (rst_n) begin
      if (app_en && !calib_done) fail("app_en asserted before calib_done rose");
      if (app_en && app_addr[3:0] != 4'h0)
        fail("app_addr not aligned to the 16 byte transaction size");
      if (ic_resp_ready && dc_resp_ready)
        fail("instruction and data response ready both high in one cycle");
      if (ic_resp_ready && !core_en) fail("instruction response ready high while core_en is low");
      if (dc_resp_ready && !core_en) fail("data response ready high while core_en is low");
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
    rst_n      = 1'b0;
    calib_done = 1'b0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);
    calib_done = 1'b1;
    @(posedge clk);
  endtask  // Automatic

  task automatic wait_ic();
    int guard;
    bit seen;
    guard = 0;
    seen  = 1'b0;
    while (!seen) begin
      @(posedge clk);
      #1;
      if (ic_resp_ready) seen = 1'b1;
      guard++;
      if (guard > 4000)
        $fatal(1, "t=%0t  instruction request held valid 4000 cycles with no response ready",
               $time);
    end
  endtask  // Automatic

  task automatic wait_dc();
    int guard;
    bit seen;
    guard = 0;
    seen  = 1'b0;
    while (!seen) begin
      @(posedge clk);
      #1;
      if (dc_resp_ready) seen = 1'b1;
      guard++;
      if (guard > 4000)
        $fatal(1, "t=%0t  data request held valid 4000 cycles with no response ready", $time);
    end
  endtask  // Automatic

  task automatic ic_read(input logic [Xlen-1:0] addr, output logic [LineBits-1:0] data);
    #1;
    ic_req_valid = 1'b1;
    ic_req_addr  = addr;
    wait_ic();
    data = ic_resp_rdata;
    ic_req_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic dc_read(input logic [Xlen-1:0] addr, output logic [LineBits-1:0] data);
    #1;
    dc_req_valid = 1'b1;
    dc_req_rw    = 1'b0;
    dc_req_addr  = addr;
    dc_req_wstrb = 4'h0;
    wait_dc();
    data = dc_resp_rdata;
    dc_req_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic dc_write(input logic [Xlen-1:0] addr, input logic [LineBits-1:0] data);
    #1;
    dc_req_valid = 1'b1;
    dc_req_rw    = 1'b1;
    dc_req_addr  = addr;
    dc_req_wdata = data;
    dc_req_wstrb = 4'h0;
    wait_dc();
    dc_req_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic dc_word_write(input logic [Xlen-1:0] addr, input logic [3:0] strb,
                               input logic [Xlen-1:0] data);
    #1;
    dc_req_valid = 1'b1;
    dc_req_rw    = 1'b1;
    dc_req_addr  = addr;
    dc_req_wdata = LineBits'(data);
    dc_req_wstrb = strb;
    wait_dc();
    dc_req_valid = 1'b0;
    dc_req_wstrb = 4'h0;
    @(posedge clk);
  endtask  // Automatic

  task automatic boot_word(input logic [Xlen-1:0] addr, input logic [Xlen-1:0] data);
    #1;
    boot_we    = 1'b1;
    boot_addr  = addr;
    boot_wdata = data;
    repeat (en_period) @(posedge clk);
    #1;
    boot_we = 1'b0;
    repeat (40) @(posedge clk);
  endtask  // Automatic

  logic [LineBits-1:0] ic_got;
  logic [LineBits-1:0] dc_got;

  task automatic both_read(input logic [Xlen-1:0] ic_a, input logic [Xlen-1:0] dc_a);
    fork
      ic_read(ic_a, ic_got);
      dc_read(dc_a, dc_got);
    join
  endtask  // Automatic

  logic [LineBits-1:0] got;

  initial begin
    $dumpfile("mem_arb_tb.vcd");
    $dumpvars(0, mem_arb_tb);

    clk          = 1'b0;
    rst_n        = 1'b1;
    calib_done   = 1'b0;
    ic_req_valid = 1'b0;
    ic_req_addr  = '0;
    dc_req_valid = 1'b0;
    dc_req_rw    = 1'b0;
    dc_req_addr  = '0;
    dc_req_wdata = '0;
    dc_req_wstrb = 4'h0;
    boot_we      = 1'b0;
    boot_addr    = '0;
    boot_wdata   = '0;

    for (int i = 0; i < MemLines; i++) mem[i] = '0;
    for (int i = 0; i <= RdLat; i++) rd_d[i] = '0;

    do_reset();

    // Boot lane sweep
    boot_word(32'h0000_0000, 32'hAAAA_0000);
    boot_word(32'h0000_0004, 32'hAAAA_0001);
    boot_word(32'h0000_0008, 32'hAAAA_0002);
    boot_word(32'h0000_000C, 32'hAAAA_0003);

    ic_read(32'h0000_0000, got);
    check("line of four boot word writes reads back wrong", got,
          {32'hAAAA_0003, 32'hAAAA_0002, 32'hAAAA_0001, 32'hAAAA_0000});

    // Boot leaves neighbours
    ic_read(32'h0000_0010, got);
    check("boot word write disturbed the next line up", got, '0);

    // One lane only
    boot_word(32'h0000_0014, 32'hCCCC_0001);
    ic_read(32'h0000_0010, got);
    check("boot word write disturbed the other three words", got,
          {32'h0, 32'h0, 32'hCCCC_0001, 32'h0});

    // Dirty line writeback
    dc_write(32'h0000_0020, {32'hBBBB_0003, 32'hBBBB_0002, 32'hBBBB_0001, 32'hBBBB_0000});
    dc_read(32'h0000_0020, got);
    check("line reads back wrong after a data cache write", got,
          {32'hBBBB_0003, 32'hBBBB_0002, 32'hBBBB_0001, 32'hBBBB_0000});

    // Full line overwrite
    dc_write(32'h0000_0000, {32'hDDDD_0003, 32'hDDDD_0002, 32'hDDDD_0001, 32'hDDDD_0000});
    ic_read(32'h0000_0000, got);
    check("full line write left previous bytes in place", got,
          {32'hDDDD_0003, 32'hDDDD_0002, 32'hDDDD_0001, 32'hDDDD_0000});

    // Requester tagging
    dc_write(32'h0000_0100, {32'h1111_0003, 32'h1111_0002, 32'h1111_0001, 32'h1111_0000});
    dc_write(32'h0000_0200, {32'h2222_0003, 32'h2222_0002, 32'h2222_0001, 32'h2222_0000});
    both_read(32'h0000_0100, 32'h0000_0200);
    check("concurrent reads: instruction response has the wrong line", ic_got,
          {32'h1111_0003, 32'h1111_0002, 32'h1111_0001, 32'h1111_0000});
    check("concurrent reads: data response has the wrong line", dc_got,
          {32'h2222_0003, 32'h2222_0002, 32'h2222_0001, 32'h2222_0000});

    // Word lane sweep
    for (int w = 0; w < 4; w++) begin
      logic [LineBits-1:0] base;
      logic [LineBits-1:0] want;
      base = {32'h8888_0003, 32'h8888_0002, 32'h8888_0001, 32'h8888_0000};
      dc_write(32'h0000_0400, base);
      want = base;
      want[w*32+:32] = 32'h9999_0000 + Xlen'(w);
      dc_word_write(32'h0000_0400 + Xlen'(w * 4), 4'hF, 32'h9999_0000 + Xlen'(w));
      ic_read(32'h0000_0400, got);
      check($sformatf("data cache word write hit the wrong word, word %0d", w), got, want);
    end

    // Byte strobe sweep
    begin
      logic [LineBits-1:0] base;
      logic [LineBits-1:0] want;
      logic [         3:0] strobes[4];
      strobes[0] = 4'b0001;
      strobes[1] = 4'b1100;
      strobes[2] = 4'b0110;
      strobes[3] = 4'b1111;
      for (int s = 0; s < 4; s++) begin
        base = {32'hABAB_0003, 32'hABAB_0002, 32'hABAB_0001, 32'hABAB_0000};
        dc_write(32'h0000_0500, base);
        want = base;
        for (int b = 0; b < 4; b++) begin
          if (strobes[s][b]) want[32+b*8+:8] = 8'h5A + 8'(b);
        end
        dc_word_write(32'h0000_0504, strobes[s], {8'h5D, 8'h5C, 8'h5B, 8'h5A});
        dc_read(32'h0000_0500, got);
        check($sformatf(
                  "data cache word write ignored byte strobe %04b", strobes[s]), got, want);
      end
    end

    // Word write neighbours
    dc_write(32'h0000_0600, {32'hFEED_0003, 32'hFEED_0002, 32'hFEED_0001, 32'hFEED_0000});
    dc_write(32'h0000_0610, {32'hF00D_0003, 32'hF00D_0002, 32'hF00D_0001, 32'hF00D_0000});
    dc_word_write(32'h0000_0608, 4'hF, 32'h0BAD_0000);
    ic_read(32'h0000_0610, got);
    check("data cache word write disturbed the next line up", got,
          {32'hF00D_0003, 32'hF00D_0002, 32'hF00D_0001, 32'hF00D_0000});

    // Word write stalled
    en_period = 3;
    rdy_pct   = 30;
    wdf_pct   = 30;
    for (int i = 0; i < 8; i++) begin
      logic [Xlen-1:0] a;
      a = 32'h0000_0700 + Xlen'((i % 4) * 4);
      dc_write(32'h0000_0700, '0);
      dc_word_write(a, 4'hF, 32'hC0DE_0000 + Xlen'(i));
      ic_read(32'h0000_0700, got);
      check($sformatf(
                "data cache word write lost under a stalling controller, pass %0d", i), got,
            LineBits'(32'hC0DE_0000 + Xlen'(i)) << ((i % 4) * 32));
    end
    en_period = 1;
    rdy_pct   = 100;
    wdf_pct   = 100;

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
        @(posedge clk);
        dc_write(32'h0000_0300,
                 {32'h3333_0003, 32'h3333_0002, 32'h3333_0001, 32'h3333_0000} + LineBits'(p));
        ic_read(32'h0000_0300, got);
        check($sformatf(
                  "read after write reads back wrong, core_en 1 cycle in %0d", en_period), got,
              {32'h3333_0003, 32'h3333_0002, 32'h3333_0001, 32'h3333_0000} + LineBits'(p));
        boot_word(32'h0000_0310, 32'hEEEE_0000 + Xlen'(p));
        ic_read(32'h0000_0310, got);
        check($sformatf("boot word write did not land, core_en 1 cycle in %0d",
                        en_period), got, {32'h0, 32'h0, 32'h0, 32'hEEEE_0000 + Xlen'(p)});
      end
      en_period = 1;
    end

    // Stalled controller
    rdy_pct = 25;
    wdf_pct = 15;
    for (int i = 0; i < 24; i++) begin
      logic [Xlen-1:0] a;
      logic [LineBits-1:0] d;
      a = 32'h0000_1000 + (i * 16);
      d = {32'h4444_0003 + i, 32'h4444_0002 + i, 32'h4444_0001 + i, 32'h4444_0000 + i};
      dc_write(a, d);
      ic_read(a, got);
      check($sformatf(
                "read after write reads back wrong under a stalling controller, pass %0d",
                i), got, d);
    end
    rdy_pct   = 100;
    wdf_pct   = 100;

    // Slow core stalled
    en_period = 4;
    rdy_pct   = 40;
    wdf_pct   = 40;
    for (int i = 0; i < 12; i++) begin
      logic [Xlen-1:0] a;
      logic [LineBits-1:0] d;
      a = 32'h0000_2000 + (i * 16);
      d = {32'h5555_0003 + i, 32'h5555_0002 + i, 32'h5555_0001 + i, 32'h5555_0000 + i};
      dc_write(a, d);
      ic_read(a, got);
      check($sformatf(
                "read after write reads back wrong, stalling controller and slow core, pass %0d",
                i), got, d);
    end
    en_period = 1;
    rdy_pct   = 100;
    wdf_pct   = 100;

    // Fast controller
    for (int L = 0; L <= 3; L++) begin
      logic [Xlen-1:0] a;
      logic [LineBits-1:0] d;
      rd_lat = L;
      a = 32'h0000_3000 + ((L + 1) * 16);
      d = {32'h6666_0003 + L, 32'h6666_0002 + L, 32'h6666_0001 + L, 32'h6666_0000 + L};
      dc_write(a, d);
      ic_read(a, got);
      check($sformatf("read after write reads back wrong at a read latency of %0d", L), got, d);
      boot_word(a + 4, 32'h7777_0000 + Xlen'(L));
      dc_read(a, got);
      check($sformatf("boot word write did not land at a read latency of %0d", L), got,
            {d[127:64], 32'h7777_0000 + Xlen'(L), d[31:0]});
    end
    rd_lat = RdLat;

    check_int("commands left outstanding at the controller when the stimulus ended", cq_wr,
                cq_rd);
    check_int("write beats left outstanding at the controller when the stimulus ended",
                wq_wr, wq_rd);

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

  initial begin
    #4000000;
    $fatal(1, "global time limit reached before the stimulus finished");
  end

endmodule
