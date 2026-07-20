module board_irq_tb ();

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

  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;
  localparam int RxBitFast = ((CoreClkHz + BaudRate / 2) / BaudRate) * ClkDiv;

  localparam int NWords = 32;
  logic [31:0] prog[NWords];

  string exp = "IT\n";

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

  // Sample bit centers
  task automatic recv_byte(output logic [7:0] b);
    @(negedge uart_tx);
    repeat (RxBitFast / 2) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      repeat (RxBitFast) @(posedge clk);
      b[i] = uart_tx;
    end
    repeat (RxBitFast) @(posedge clk);
  endtask  // Automatic

  task automatic check(input string name, input logic [7:0] got, input logic [7:0] exp_b);
    checks++;
    if (got !== exp_b) begin
      $error("%s got %02x exp %02x", name, got, exp_b);
      errors++;
    end
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  logic [7:0] rxb[3];

  // Watchdog
  initial begin
    repeat (5_000_000) @(posedge clk);
    $fatal(1, "TIMEOUT before the interrupt fired");
  end

  initial begin
    $dumpfile("board_irq_tb.vcd");
    $dumpvars(0, board_irq_tb);
    $readmemh("tests/timer_irq.hex", prog);
    do_reset();

    // Load the program, then catch the print the trap handler emits
    send_word(NWords);
    foreach (prog[i]) send_word(prog[i]);

    for (int i = 0; i < exp.len(); i++) recv_byte(rxb[i]);
    for (int i = 0; i < exp.len(); i++)
      check($sformatf("byte%0d", i), rxb[i], 8'(exp[i]));
    verdict();
  end

endmodule
