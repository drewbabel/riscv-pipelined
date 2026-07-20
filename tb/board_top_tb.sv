module board_top_tb ();

  int          checks = 0;
  int          errors = 0;

  logic        clk = 1'b0;
  logic        rst;
  logic [15:0] sw;
  logic [15:0] led;
  logic        uart_rx = 1'b1;
  logic        uart_tx;

  localparam int FastClkHz = 100_000_000;
  localparam int ClkDiv = 32;
  localparam int CoreClkHz = FastClkHz / ClkDiv;
  localparam int BaudRate = 28_800;

  // Bit period in fast clocks, core samples at CoreClkHz
  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;

  logic [31:0] prog[8];

  always #5 clk = ~clk;

  board_top #(
      .DEPTH(1024)
  ) dut (
      .clk    (clk),
      .rst    (rst),
      .sw     (sw),
      .led    (led),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx)
  );

  task automatic do_reset();
    rst = 1;
    sw = 16'h0;
    uart_rx = 1'b1;
    repeat (2) @(posedge clk);
    rst = 0;
    repeat (200) @(posedge clk);
  endtask  // Automatic

  task automatic send_byte(input logic [7:0] b);
    uart_rx = 1'b0;
    repeat (ClksPerBit) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      uart_rx = b[i];
      repeat (ClksPerBit) @(posedge clk);
    end
    uart_rx = 1'b1;
    repeat (ClksPerBit) @(posedge clk);
  endtask  // Automatic

  task automatic send_word(input logic [31:0] w);
    for (int j = 0; j < 32; j += 8) send_byte(w[j+:8]);
  endtask  // Automatic

  task automatic check(input string name, input logic [15:0] got, input logic [15:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s got %04x exp %04x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  // Round-trip a word through mem to the LEDs
  initial begin
    $dumpfile("board_top_tb.vcd");
    $dumpvars(0, board_top_tb);
    $readmemh("tests/memtest.hex", prog);
    do_reset();

    send_word(32'd8);
    foreach (prog[i]) send_word(prog[i]);

    wait (dut.loading == 1'b0);
    repeat (200) @(posedge clk);
    check("led", led, 16'hABCD);
    verdict();
  end

endmodule
