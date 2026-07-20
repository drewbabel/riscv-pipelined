module uart_tx_tb ();

  int   checks = 0;
  int   errors = 0;

  logic clk = 1'b0;
  logic core_en;
  logic rst_n;
  logic [7:0] tx_data;
  logic tx_valid;
  logic tx_ready;
  logic tx_serial;

  localparam int ClkFreqHz = 3_125_000;
  localparam int BaudRate = 28_800;
  localparam int ClkDiv = 32;
  localparam int BitFast = ((ClkFreqHz + BaudRate / 2) / BaudRate) * ClkDiv;

  always #5 clk = ~clk;

  // Core enable pulse
  logic [4:0] div = '0;
  always_ff @(posedge clk) div <= div + 1'b1;
  assign core_en = (div == 5'd0);

  uart_tx #(
      .CLK_FREQ_HZ(ClkFreqHz),
      .BAUD_RATE  (BaudRate)
  ) dut (
      .clk      (clk),
      .core_en  (core_en),
      .rst_n    (rst_n),
      .tx_data  (tx_data),
      .tx_valid (tx_valid),
      .tx_ready (tx_ready),
      .tx_serial(tx_serial)
  );

  task automatic do_reset();
    rst_n = 0;
    tx_valid = 0;
    tx_data = '0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (4) @(posedge clk);
  endtask  // Automatic

  task automatic send(input logic [7:0] b);
    @(posedge clk);
    wait (tx_ready);
    #1;
    tx_data  = b;
    tx_valid = 1'b1;
    do @(posedge clk); while (!(core_en && tx_ready));
    #1;
    tx_valid = 1'b0;
  endtask  // Automatic

  task automatic recv(output logic [7:0] b);
    @(negedge tx_serial);
    repeat (BitFast / 2) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      repeat (BitFast) @(posedge clk);
      b[i] = tx_serial;
    end
    repeat (BitFast) @(posedge clk);
  endtask  // Automatic

  task automatic check(input string name, input logic [7:0] got, input logic [7:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s got %02x exp %02x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  logic [7:0] pat[4];
  logic [7:0] got;

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, uart_tx_tb);
    pat[0] = 8'h41;
    pat[1] = 8'h55;
    pat[2] = 8'h00;
    pat[3] = 8'hFF;
    do_reset();

    check("idle_high", tx_serial, 1'b1);
    check("ready_after_reset", {7'b0, tx_ready}, 8'h01);

    fork
      foreach (pat[i]) send(pat[i]);
      foreach (pat[i]) begin
        recv(got);
        check($sformatf("byte%0d", i), got, pat[i]);
      end
    join

    verdict();
  end

endmodule
