module board_top #(
    parameter int XLEN  = 32,
    parameter int DEPTH = 16384
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

  logic            rst_n;
  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] instr_raw;
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] mem_addr;
  logic [     3:0] store_wstrb;
  logic [XLEN-1:0] store_data;

  logic [XLEN-1:0] read_data;
  logic [XLEN-1:0] mem_rdata;
  logic [XLEN-1:0] clint_rdata;
  logic [XLEN-1:0] gpio_rdata;
  logic [XLEN-1:0] uart_rdata;
  logic            clint_sel;
  logic            gpio_sel;
  logic            uart_sel;
  logic            tx_ready;
  logic            tx_valid;
  logic [    15:0] led_reg;

  logic            core_rst_n;
  logic            loading;
  logic            boot_we;
  logic [XLEN-1:0] boot_waddr;
  logic [XLEN-1:0] boot_wdata;
  logic [     7:0] rx_byte;
  logic            rx_valid_w;

  logic [XLEN-1:0] mem_daddr;
  logic [XLEN-1:0] mem_wdata;
  logic [     3:0] mem_wstrb;

  logic [XLEN-1:0] rt_addr_q;
  logic [XLEN-1:0] rt_data_q;
  logic [     3:0] rt_strb_q;

  // Core-enable divider
  logic [     4:0] div = '0;
  logic            core_en;
  always_ff @(posedge clk) div <= div + 1'b1;
  assign core_en = (div == 5'd0);

  // Power-on reset
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

  // Peripheral read mux
  always_comb begin
    if (uart_sel) read_data = uart_rdata;
    else if (gpio_sel) read_data = gpio_rdata;
    else if (clint_sel) read_data = clint_rdata;
    else read_data = mem_rdata;
  end

  // Serial transmit register
  assign uart_rdata = {31'b0, tx_ready};
  assign tx_valid   = core_en && uart_sel && !mem_addr[2] && |store_wstrb;

  // GPIO read mux
  assign gpio_rdata = mem_addr[2] ? {16'b0, sw} : {16'b0, led_reg};
  assign led        = loading ? 16'h5555 : led_reg;
  always_ff @(posedge clk) begin
    if (!core_rst_n) led_reg <= '0;
    else if (core_en && gpio_sel && !mem_addr[2] && |store_wstrb) led_reg <= store_data[15:0];
  end

  // Registered store path
  always_ff @(posedge clk) begin
    rt_addr_q <= mem_addr;
    rt_data_q <= store_data;
    rt_strb_q <= (clint_sel || gpio_sel || uart_sel) ? 4'b0 : store_wstrb;
  end

  // Boot write mux
  assign mem_daddr = loading ? boot_waddr : rt_addr_q;
  assign mem_wdata = loading ? boot_wdata : rt_data_q;
  always_comb begin
    if (!loading) mem_wstrb = rt_strb_q;
    else if (boot_we) mem_wstrb = 4'hF;
    else mem_wstrb = 4'b0;
  end

  uart_rx #(
      .CLK_FREQ_HZ(3_125_000),
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
      .CLK_FREQ_HZ(3_125_000),
      .BAUD_RATE  (28_800)
  ) uart_tx_inst (
      .clk      (clk),
      .core_en  (core_en),
      .rst_n    (rst_n),
      .tx_data  (store_data[7:0]),
      .tx_valid (tx_valid),
      .tx_ready (tx_ready),
      .tx_serial(uart_tx)
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
      .pc         (pc),
      .mem_write  (),
      .alu_result (),
      .write_data (),
      .store_wstrb(store_wstrb),
      .store_data (store_data),
      .mem_addr   (mem_addr)
  );

  // Split fetch data mem
  mem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) imem_inst (
      .clk    (clk),
      .core_en(core_en),
      .iaddr  (pc),
      .instr  (instr_raw),
      .wstrb  (loading ? (boot_we ? 4'hF : 4'b0) : 4'b0),
      .daddr  (boot_waddr),
      .wdata  (boot_wdata),
      .rdata  ()
  );

  mem #(
      .XLEN (XLEN),
      .DEPTH(DEPTH)
  ) dmem_inst (
      .clk    (clk),
      .core_en(core_en),
      .iaddr  ('0),
      .instr  (),
      .wstrb  (mem_wstrb),
      .daddr  (mem_daddr),
      .wdata  (mem_wdata),
      .rdata  (mem_rdata)
  );

  // irq unwired
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
      .timer_irq()
  );

endmodule
