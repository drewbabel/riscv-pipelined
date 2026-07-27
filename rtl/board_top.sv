module board_top
  import cache_pkg::*;
#(
    parameter int XLEN   = 32,
    parameter int DEPTH  = 16384,
    parameter int ClkDiv = 32,
    parameter int MemLatency = 20
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] sw,
    output logic [15:0] led,
    input  logic        uart_rx,
    output logic        uart_tx
);

  localparam logic [7:0] ClintTag = 8'h02;
  localparam logic [7:0] GpioTag = 8'h03;
  localparam logic [7:0] UartTag = 8'h04;
  localparam logic [7:0] StatsTag = 8'h05;

  logic            rst_n;
  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] instr_raw;
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
  logic [    15:0] led_reg;

  logic            core_rst_n;
  logic            loading;
  logic            boot_we;
  logic [XLEN-1:0] boot_waddr;
  logic [XLEN-1:0] boot_wdata;
  logic [     7:0] rx_byte;
  logic            rx_valid_w;


  logic [XLEN-1:0] stats_rdata;
  logic            stats_sel;
  logic            periph_sel;

  logic            imem_ready;
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
  logic [LineBits-1:0] dc_mem_rdata;
  logic                dc_mem_ready;

  logic [31:0] ic_hits;
  logic [31:0] ic_misses;
  logic [31:0] dc_hits;
  logic [31:0] dc_misses;

  // Core enable divider
  localparam int CoreClkHz = 100_000_000 / ClkDiv;
  localparam logic [$clog2(ClkDiv)-1:0] DivMax = $clog2(ClkDiv)'(ClkDiv - 1);
  logic [$clog2(ClkDiv)-1:0] div = '0;
  logic                      core_en;
  always_ff @(posedge clk) div <= (div == DivMax) ? '0 : div + 1'b1;
  assign core_en = (div == 0);

  // Power on reset
  logic [3:0] por = '0;
  always_ff @(posedge clk) if (core_en && !por[3]) por <= por + 1'b1;
  assign rst_n      = por[3] & ~rst;

  // Load holds reset
  assign core_rst_n = rst_n & ~loading;

  assign instr      = instr_raw;

  // Decode on mem_addr
  assign clint_sel  = mem_addr[31:24] == ClintTag;
  assign gpio_sel   = mem_addr[31:24] == GpioTag;
  assign uart_sel   = mem_addr[31:24] == UartTag;
  assign stats_sel  = mem_addr[31:24] == StatsTag;
  assign periph_sel = clint_sel || gpio_sel || uart_sel || stats_sel;

  // Peripheral read mux
  always_comb begin
    if (uart_sel) read_data = uart_rdata;
    else if (gpio_sel) read_data = gpio_rdata;
    else if (clint_sel) read_data = clint_rdata;
    else if (stats_sel) read_data = stats_rdata;
    else read_data = dc_rdata;
  end

  // Cache counters
  always_comb begin
    case (mem_addr[3:2])
      2'd0: stats_rdata = ic_hits;
      2'd1: stats_rdata = ic_misses;
      2'd2: stats_rdata = dc_hits;
      default: stats_rdata = dc_misses;
    endcase
  end

  assign dmem_ready = periph_sel ? 1'b1 : dc_ready;

  // GPIO read mux
  assign gpio_rdata = mem_addr[2] ? {16'b0, sw} : {16'b0, led_reg};
  assign led        = loading ? 16'h5555 : led_reg;
  always_ff @(posedge clk) begin
    if (!core_rst_n) led_reg <= '0;
    else if (core_en && gpio_sel && !mem_addr[2] && |store_wstrb) led_reg <= store_data[15:0];
  end

  uart_rx #(
      .CLK_FREQ_HZ(CoreClkHz),
      .BAUD_RATE  (28_800)
  ) uart_rx_inst (
      .clk      (clk),
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
      .clk      (clk),
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
      .clk     (clk),
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
      .clk     (clk),
      .core_en (core_en),
      .rst_n   (rst_n),
      .rx_valid(rx_valid_w),
      .rx_data (rx_byte),
      .we      (boot_we),
      .waddr   (boot_waddr),
      .wdata   (boot_wdata),
      .loading (loading)
  );

  riscv_pipelined #(
      .XLEN(XLEN)
  ) riscv_pipelined_inst (
      .clk        (clk),
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

  icache #(
      .XLEN(XLEN)
  ) icache_inst (
      .clk       (clk),
      .core_en   (core_en),
      .rst_n     (core_rst_n),
      .cpu_valid (1'b1),
      .cpu_addr  (pc),
      .cpu_rdata (instr_raw),
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
      .clk       (clk),
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

  mem_delay #(
      .XLEN   (XLEN),
      .DEPTH  (DEPTH),
      .Latency(MemLatency)
  ) imem_inst (
      .clk       (clk),
      .core_en   (core_en),
      .rst_n     (rst_n),
      .req_valid (ic_mem_valid),
      .req_rw    (1'b0),
      .req_addr  (ic_mem_addr),
      .req_wdata ('0),
      .resp_rdata(ic_mem_rdata),
      .resp_ready(ic_mem_ready),
      .boot_we   (loading && boot_we),
      .boot_addr (boot_waddr),
      .boot_wdata(boot_wdata)
  );

  mem_delay #(
      .XLEN   (XLEN),
      .DEPTH  (DEPTH),
      .Latency(MemLatency)
  ) dmem_inst (
      .clk       (clk),
      .core_en   (core_en),
      .rst_n     (rst_n),
      .req_valid (dc_mem_valid),
      .req_rw    (dc_mem_rw),
      .req_addr  (dc_mem_addr),
      .req_wdata (dc_mem_wdata),
      .resp_rdata(dc_mem_rdata),
      .resp_ready(dc_mem_ready),
      .boot_we   (loading && boot_we),
      .boot_addr (boot_waddr),
      .boot_wdata(boot_wdata)
  );

  clint #(
      .XLEN(XLEN)
  ) clint_inst (
      .clk      (clk),
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
