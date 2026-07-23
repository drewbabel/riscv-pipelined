module freertos_boot_tb ();
  localparam int DEPTH = 16384;
  localparam int FastClkHz = 100_000_000;
  localparam int BaudRate = 28_800;
  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;
  localparam int SettleCycles = 3_000_000;

  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];

  int checks = 0;
  int errors = 0;

  always #5 clk = ~clk;

  board_top #(
      .DEPTH(DEPTH)
  ) dut (
      .clk(clk),
      .rst(rst),
      .sw(sw),
      .led(led),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx)
  );

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, switches reach LEDs via the queue", checks);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  //automatic

  task automatic send_byte(input logic [7:0] b);
    uart_rx = 0;
    repeat (ClksPerBit) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      uart_rx = b[i];
      repeat (ClksPerBit) @(posedge clk);
    end
    uart_rx = 1;
    repeat (ClksPerBit) @(posedge clk);
  endtask  // Automatic

  task automatic check(input string name, input logic [15:0] got, input logic [15:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s: got %04x exp %04x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  // Drive switch pattern, wait until appears on LEDs
  task automatic drive_and_check(input string name, input logic [15:0] pattern);
    int i = 0;
    sw = pattern;
    while (i < SettleCycles && led !== pattern) begin
      @(posedge clk);
      i++;
    end
    check(name, led, pattern);
  endtask  // Automatic

  initial begin
    for (int k = 0; k < DEPTH; k++) img[k] = 32'hDEADBEEF;
    $readmemh("sw/freertos/freertos_sim.hex", img);
    #1;  // after mem init
    for (int k = 0; k < DEPTH; k++) begin
      dut.imem_inst.g_lane[0].bmem[k] = img[k][7:0];
      dut.imem_inst.g_lane[1].bmem[k] = img[k][15:8];
      dut.imem_inst.g_lane[2].bmem[k] = img[k][23:16];
      dut.imem_inst.g_lane[3].bmem[k] = img[k][31:24];
      dut.dmem_inst.g_lane[0].bmem[k] = img[k][7:0];
      dut.dmem_inst.g_lane[1].bmem[k] = img[k][15:8];
      dut.dmem_inst.g_lane[2].bmem[k] = img[k][23:16];
      dut.dmem_inst.g_lane[3].bmem[k] = img[k][31:24];
    end
    rst = 1;
    sw  = 0;
    repeat (2) @(posedge clk);
    rst = 0;
    repeat (2000) @(posedge clk);
    repeat (4) send_byte(8'd0);
    drive_and_check("queue_pattern_a", 16'hA5A5);
    drive_and_check("queue_pattern_b", 16'h3C3C);

    verdict();
  end
endmodule
