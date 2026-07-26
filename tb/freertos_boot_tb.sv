module freertos_boot_tb ();

  import cache_pkg::*;
  localparam int DEPTH = 16384;
  localparam int FastClkHz = 100_000_000;
  localparam int BaudRate = 28_800;
  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;
  localparam int SettleCycles = 6_000_000;

  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];
  logic [LineBits-1:0] pline;

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

  // Switches reach LEDs
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
    rst = 1;
    for (int k = 0; k < DEPTH; k++) img[k] = 32'hDEADBEEF;
    $readmemh("sw/freertos/freertos_sim.hex", img);
    if (img[0] == 32'hDEADBEEF)
      $fatal(1, "freertos_sim.hex missing or empty, run make -C sw/freertos all");
    #1;  // After mem init
    for (int l = 0; l < DEPTH / LineWords; l++) begin
      for (int w = 0; w < LineWords; w++) pline[32*w+:32] = img[l*LineWords+w];
      @(negedge clk);
      dut.imem_inst.u_line.bd_idx  = l;
      dut.imem_inst.u_line.bd_data = pline;
      dut.imem_inst.u_line.bd_we   = 1'b1;
      dut.dmem_inst.u_line.bd_idx  = l;
      dut.dmem_inst.u_line.bd_data = pline;
      dut.dmem_inst.u_line.bd_we   = 1'b1;
    end
    @(negedge clk);
    dut.imem_inst.u_line.bd_we = 1'b0;
    dut.dmem_inst.u_line.bd_we = 1'b0;
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
