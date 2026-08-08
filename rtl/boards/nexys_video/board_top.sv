module board_top
  import cache_pkg::*;
#(
    parameter int XLEN      = 32,
    parameter int DEPTH     = 16384,
    parameter int ClkDiv    = 2,
    parameter bit UNCACHED  = 1'b0,
    parameter bit GSHARE_EN = 1'b1,
    parameter bit SINGLE_CYCLE = 1'b0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [ 7:0] sw,
    output logic [ 7:0] led,
    input  logic        uart_rx,
    output logic        uart_tx,
    // DDR3
    output logic [14:0] ddr3_addr,
    output logic [ 2:0] ddr3_ba,
    output logic        ddr3_ras_n,
    output logic        ddr3_cas_n,
    output logic        ddr3_we_n,
    output logic        ddr3_reset_n,
    output logic [ 0:0] ddr3_ck_p,
    output logic [ 0:0] ddr3_ck_n,
    output logic [ 0:0] ddr3_cke,
    output logic [ 0:0] ddr3_odt,
    output logic [ 1:0] ddr3_dm,
    inout  wire  [15:0] ddr3_dq,
    inout  wire  [ 1:0] ddr3_dqs_p,
    inout  wire  [ 1:0] ddr3_dqs_n
);

  localparam logic [7:0] ClintTag = 8'h02;
  localparam logic [7:0] GpioTag = 8'h03;
  localparam logic [7:0] UartTag = 8'h04;
  localparam logic [7:0] PmuTag = 8'h05;

  localparam int AppAddrWidth = 29;
  localparam int MaskBits = LineBits / 8;

  logic            rst_n;
  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] mem_addr;
  logic [     3:0] store_wstrb;
  logic [XLEN-1:0] store_data;

  logic [XLEN-1:0] read_data;
  logic [XLEN-1:0] clint_rdata;
  logic [XLEN-1:0] gpio_rdata;
  logic [XLEN-1:0] uart_rdata;
  logic            clint_sel;
  logic            gpio_sel;
  logic            uart_sel;
  logic            tx_ready;
  logic            timer_irq;
  logic            ext_irq;
  logic            tx_valid;
  logic [     7:0] tx_byte;
  logic [     7:0] led_raw;

  logic            core_rst_n;
  logic            loading;
  logic            boot_we;
  logic [XLEN-1:0] boot_waddr;
  logic [XLEN-1:0] boot_wdata;
  logic [     7:0] rx_byte;
  logic            rx_valid_w;

  logic [XLEN-1:0] pmu_rdata;
  logic            pmu_sel;
  logic            periph_sel;

  logic            imem_ready;
  logic            imem_req;
  logic            dmem_ready;
  logic            dmem_req;
  logic            dc_ready;
  logic [XLEN-1:0] dc_rdata;

  logic                ic_mem_valid;
  logic [    XLEN-1:0] ic_mem_addr;
  logic [LineBits-1:0] ic_mem_rdata;
  logic                ic_mem_ready;

  logic                dc_mem_valid;
  logic                dc_mem_rw;
  logic [    XLEN-1:0] dc_mem_addr;
  logic [LineBits-1:0] dc_mem_wdata;
  logic [         3:0] dc_mem_wstrb;
  logic [LineBits-1:0] dc_mem_rdata;
  logic                dc_mem_ready;

  logic         [31:0] ic_hits;
  logic         [31:0] ic_misses;
  logic         [31:0] dc_hits;
  logic         [31:0] dc_misses;

  // Controller clocks
  logic                pll_fb;
  logic                pll_locked;
  logic                sys_clk_pll;
  logic                ref_clk_pll;
  logic                mig_sys_clk;
  logic                mig_ref_clk;
  logic                mig_rst_n;

  // Controller application
  logic                core_clk;
  logic                ui_rst;
  logic                calib_done;

  logic [AppAddrWidth-1:0] app_addr;
  logic [             2:0] app_cmd;
  logic                    app_en;
  logic                    app_rdy;
  logic [    LineBits-1:0] app_wdf_data;
  logic [    MaskBits-1:0] app_wdf_mask;
  logic                    app_wdf_wren;
  logic                    app_wdf_end;
  logic                    app_wdf_rdy;
  logic [    LineBits-1:0] app_rd_data;
  logic                    app_rd_data_valid;

  localparam int CoreClkHz = 100_000_000 / ClkDiv;
  logic core_en;

  PLLE2_BASE #(
      .CLKIN1_PERIOD (10.000),
      .CLKFBOUT_MULT (10),
      .CLKOUT0_DIVIDE(10),
      .CLKOUT1_DIVIDE(5)
  ) pll_inst (
      .CLKIN1  (clk),
      .CLKFBIN (pll_fb),
      .CLKFBOUT(pll_fb),
      .CLKOUT0 (sys_clk_pll),
      .CLKOUT1 (ref_clk_pll),
      .CLKOUT2 (),
      .CLKOUT3 (),
      .CLKOUT4 (),
      .CLKOUT5 (),
      .LOCKED  (pll_locked),
      .PWRDWN  (1'b0),
      .RST     (1'b0)
  );

  BUFG sys_bufg_inst (
      .I(sys_clk_pll),
      .O(mig_sys_clk)
  );

  BUFG ref_bufg_inst (
      .I(ref_clk_pll),
      .O(mig_ref_clk)
  );

  // Active low
  assign mig_rst_n = pll_locked & ~rst;

  mig_7series_0 mig_inst (
      .ddr3_addr          (ddr3_addr),
      .ddr3_ba            (ddr3_ba),
      .ddr3_ras_n         (ddr3_ras_n),
      .ddr3_cas_n         (ddr3_cas_n),
      .ddr3_we_n          (ddr3_we_n),
      .ddr3_reset_n       (ddr3_reset_n),
      .ddr3_ck_p          (ddr3_ck_p),
      .ddr3_ck_n          (ddr3_ck_n),
      .ddr3_cke           (ddr3_cke),
      .ddr3_odt           (ddr3_odt),
      .ddr3_dm            (ddr3_dm),
      .ddr3_dq            (ddr3_dq),
      .ddr3_dqs_p         (ddr3_dqs_p),
      .ddr3_dqs_n         (ddr3_dqs_n),
      .sys_clk_i          (mig_sys_clk),
      .clk_ref_i          (mig_ref_clk),
      .sys_rst            (mig_rst_n),
      .app_addr           (app_addr),
      .app_cmd            (app_cmd),
      .app_en             (app_en),
      .app_rdy            (app_rdy),
      .app_wdf_data       (app_wdf_data),
      .app_wdf_mask       (app_wdf_mask),
      .app_wdf_wren       (app_wdf_wren),
      .app_wdf_end        (app_wdf_end),
      .app_wdf_rdy        (app_wdf_rdy),
      .app_rd_data        (app_rd_data),
      .app_rd_data_valid  (app_rd_data_valid),
      .app_rd_data_end    (),
      .app_sr_req         (1'b0),
      .app_ref_req        (1'b0),
      .app_zq_req         (1'b0),
      .app_sr_active      (),
      .app_ref_ack        (),
      .app_zq_ack         (),
      .ui_clk             (core_clk),
      .ui_clk_sync_rst    (ui_rst),
      .init_calib_complete(calib_done),
      .device_temp        ()
  );

  tick_gen #(
      .DIVISOR(ClkDiv)
  ) core_en_inst (
      .clk    (core_clk),
      .core_en(1'b1),
      .rst_n  (1'b1),
      .clr    (1'b0),
      .tick   (core_en)
  );

  // Power on reset
  logic [3:0] por = '0;
  always_ff @(posedge core_clk) if (core_en && !por[3]) por <= por + 1'b1;

  // Calibration holds reset
  assign rst_n      = por[3] & ~ui_rst & ~rst & calib_done;

  // Load holds reset
  assign core_rst_n = rst_n & ~loading;

  // Decode on mem_addr
  assign clint_sel  = mem_addr[31:24] == ClintTag;
  assign gpio_sel   = mem_addr[31:24] == GpioTag;
  assign uart_sel   = mem_addr[31:24] == UartTag;
  assign pmu_sel    = mem_addr[31:24] == PmuTag;
  assign periph_sel = clint_sel || gpio_sel || uart_sel || pmu_sel;

  // Peripheral read mux
  always_comb begin
    if (uart_sel) read_data = uart_rdata;
    else if (gpio_sel) read_data = gpio_rdata;
    else if (clint_sel) read_data = clint_rdata;
    else if (pmu_sel) read_data = pmu_rdata;
    else read_data = dc_rdata;
  end

  assign dmem_ready = periph_sel ? 1'b1 : dc_ready;

  assign led = loading ? 8'h55 : led_raw;

  pmu #(
      .XLEN(XLEN)
  ) pmu_inst (
      .addr     (mem_addr),
      .rdata    (pmu_rdata),
      .ic_hits  (ic_hits),
      .ic_misses(ic_misses),
      .dc_hits  (dc_hits),
      .dc_misses(dc_misses)
  );

  gpio #(
      .XLEN (XLEN),
      .WIDTH(8)
  ) gpio_inst (
      .clk    (core_clk),
      .core_en(core_en),
      .rst_n  (core_rst_n),
      .sel    (gpio_sel),
      .wstrb  (store_wstrb),
      .addr   (mem_addr),
      .wdata  (store_data),
      .rdata  (gpio_rdata),
      .sw     (sw),
      .led    (led_raw)
  );

  uart_rx #(
      .CLK_FREQ_HZ(CoreClkHz),
      .BAUD_RATE  (28_800)
  ) uart_rx_inst (
      .clk      (core_clk),
      .core_en  (core_en),
      .rst_n    (rst_n),
      .rx_serial(uart_rx),
      .rx_data  (rx_byte),
      .rx_valid (rx_valid_w),
      .rx_error ()
  );

  uart_tx #(
      .CLK_FREQ_HZ(CoreClkHz),
      .BAUD_RATE  (28_800)
  ) uart_tx_inst (
      .clk      (core_clk),
      .core_en  (core_en),
      .rst_n    (rst_n),
      .tx_data  (tx_byte),
      .tx_valid (tx_valid),
      .tx_ready (tx_ready),
      .tx_serial(uart_tx)
  );

  uart_ctrl #(
      .XLEN(XLEN)
  ) uart_ctrl_inst (
      .clk     (core_clk),
      .core_en (core_en),
      .rst_n   (core_rst_n),
      .sel     (uart_sel),
      .req     (dmem_req),
      .wstrb   (store_wstrb),
      .addr    (mem_addr),
      .wdata   (store_data),
      .rdata   (uart_rdata),
      .rx_valid(rx_valid_w),
      .rx_data (rx_byte),
      .tx_ready(tx_ready),
      .tx_valid(tx_valid),
      .tx_data (tx_byte),
      .irq     (ext_irq)
  );

  boot_loader #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) boot_loader_inst (
      .clk     (core_clk),
      .core_en (core_en),
      .rst_n   (rst_n),
      .rx_valid(rx_valid_w),
      .rx_data (rx_byte),
      .we      (boot_we),
      .waddr   (boot_waddr),
      .wdata   (boot_wdata),
      .loading (loading)
  );

  // Frozen fetch
  if (SINGLE_CYCLE) begin : g_single
    sc_core_top #(
        .XLEN(XLEN)
    ) sc_core_top_inst (
        .clk        (core_clk),
        .core_en    (core_en),
        .rst_n      (core_rst_n),
        .instr      (instr),
        .read_data  (read_data),
        .timer_irq  (timer_irq),
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
  end else begin : g_pipelined
    riscv_pipelined #(
        .XLEN     (XLEN),
        .GSHARE_EN(GSHARE_EN)
    ) riscv_pipelined_inst (
        .clk        (core_clk),
        .core_en    (core_en),
        .rst_n      (core_rst_n),
        .instr      (instr),
        .read_data  (read_data),
        .timer_irq  (timer_irq),
        .ext_irq    (ext_irq),
        .imem_ready (imem_ready),
        .dmem_ready (dmem_ready),
        .dmem_req   (dmem_req),
        .pc         (pc),
        .mem_write  (),
        .alu_result (),
        .write_data (),
        .store_wstrb(store_wstrb),
        .store_data (store_data),
        .mem_addr   (mem_addr)
    );

    // Fetch never pauses
    assign imem_req = 1'b1;
  end

  // Bare word paths
  if (UNCACHED) begin : g_uncached
    mem_word_if #(
        .XLEN(XLEN),
        .RW  (1'b0)
    ) icache_inst (
        .clk       (core_clk),
        .core_en   (core_en),
        .rst_n     (core_rst_n),
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
        .XLEN(XLEN),
        .RW  (1'b1)
    ) dcache_inst (
        .clk       (core_clk),
        .core_en   (core_en),
        .rst_n     (core_rst_n),
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
  end else begin : g_cached
    icache #(
        .XLEN(XLEN)
    ) icache_inst (
        .clk       (core_clk),
        .core_en   (core_en),
        .rst_n     (core_rst_n),
        .cpu_valid (imem_req),
        .cpu_addr  (pc),
        .cpu_rdata (instr),
        .cpu_ready (imem_ready),
        .mem_valid (ic_mem_valid),
        .mem_addr  (ic_mem_addr),
        .mem_rdata (ic_mem_rdata),
        .mem_ready (ic_mem_ready),
        .hit_count (ic_hits),
        .miss_count(ic_misses)
    );

    dcache #(
        .XLEN(XLEN)
    ) dcache_inst (
        .clk       (core_clk),
        .core_en   (core_en),
        .rst_n     (core_rst_n),
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
        .mem_rdata (dc_mem_rdata),
        .mem_ready (dc_mem_ready),
        .hit_count (dc_hits),
        .miss_count(dc_misses)
    );

    // Whole line writeback
    assign dc_mem_wstrb = 4'h0;
  end

  mem_arb #(
      .XLEN          (XLEN),
      .APP_ADDR_WIDTH(AppAddrWidth)
  ) mem_arb_inst (
      .clk              (core_clk),
      .rst_n            (~ui_rst),
      .core_en          (core_en),
      .calib_done       (calib_done),
      .ic_req_valid     (ic_mem_valid),
      .ic_req_addr      (ic_mem_addr),
      .ic_resp_rdata    (ic_mem_rdata),
      .ic_resp_ready    (ic_mem_ready),
      .dc_req_valid     (dc_mem_valid),
      .dc_req_rw        (dc_mem_rw),
      .dc_req_addr      (dc_mem_addr),
      .dc_req_wdata     (dc_mem_wdata),
      .dc_req_wstrb     (dc_mem_wstrb),
      .dc_resp_rdata    (dc_mem_rdata),
      .dc_resp_ready    (dc_mem_ready),
      .boot_we          (loading && boot_we),
      .boot_addr        (boot_waddr),
      .boot_wdata       (boot_wdata),
      .app_addr         (app_addr),
      .app_cmd          (app_cmd),
      .app_en           (app_en),
      .app_rdy          (app_rdy),
      .app_wdf_data     (app_wdf_data),
      .app_wdf_mask     (app_wdf_mask),
      .app_wdf_wren     (app_wdf_wren),
      .app_wdf_end      (app_wdf_end),
      .app_wdf_rdy      (app_wdf_rdy),
      .app_rd_data      (app_rd_data),
      .app_rd_data_valid(app_rd_data_valid)
  );

  clint #(
      .XLEN(XLEN)
  ) clint_inst (
      .clk      (core_clk),
      .core_en  (core_en),
      .rst_n    (core_rst_n),
      .sel      (clint_sel),
      .wstrb    (store_wstrb),
      .addr     (mem_addr),
      .wdata    (store_data),
      .rdata    (clint_rdata),
      .timer_irq(timer_irq)
  );

endmodule
