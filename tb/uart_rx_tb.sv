module uart_rx_tb ();

  int checks = 0;
  int errors = 0;
  int frames_sent = 0;
  int valid_frames = 0;

  localparam int ClkFreqHz = 100_000_000;
  localparam int BaudRate = 115_200;
  localparam int Oversample = 16;
  localparam int DataBits = 8;

  localparam int ClksPerBit = (ClkFreqHz + BaudRate / 2) / BaudRate;
  localparam int ClksPerOversample = (ClksPerBit + Oversample / 2) / Oversample;

  // TX bit period for baud-mismatch tests
  localparam int ClksPerBitFast = (ClksPerBit * 98) / 100;
  localparam int ClksPerBitSlow = (ClksPerBit * 102) / 100;
  int tx_bit = ClksPerBit;

  logic clk = 0;
  logic rst_n;
  logic rx_serial;
  logic [DataBits-1:0] rx_data;
  logic rx_valid;
  logic rx_error;

  logic exp_error;
  logic exp_valid;
  logic [DataBits-1:0] exp_data;
  logic exp_corrupt;

  always #5 clk = ~clk;

  uart_rx #(
      .CLK_FREQ_HZ(ClkFreqHz),
      .BAUD_RATE  (BaudRate),
      .OVERSAMPLE (Oversample),
      .DATA_BITS  (DataBits)
  ) dut (
      .clk(clk),
      .core_en(1'b1),
      .rst_n(rst_n),
      .rx_serial(rx_serial),
      .rx_data(rx_data),
      .rx_valid(rx_valid),
      .rx_error(rx_error)
  );

  task automatic do_reset();
    rst_n = 1'b0;
    rx_serial = 1'b1;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
    rx_serial = 1'b1;
  endtask  // Automatic

  task automatic send_data(input logic [DataBits-1:0] data, input logic corrupt);
    // Start bit (low)
    rx_serial = 1'b0;
    repeat (tx_bit) @(posedge clk);

    // Data bits
    for (int i = 0; i < $bits(data); i++) begin
      rx_serial = data[i];
      repeat (tx_bit) @(posedge clk);
    end

    // Stop bit (high)
    if (corrupt) begin
      rx_serial = 1'b0;
      repeat (tx_bit) @(posedge clk);
      rx_serial = 1'b1;
      repeat (tx_bit) @(posedge clk);
    end else begin
      rx_serial = 1'b1;
      repeat (tx_bit) @(posedge clk);
    end

    frames_sent++;
    if (!corrupt) valid_frames++;
  endtask  // Automatic

  task automatic check_data(input logic [DataBits-1:0] got_data,
                            input logic [DataBits-1:0] exp_data);
    checks++;
    if (got_data !== exp_data) begin
      errors++;
      $error("t=%0t data mismatch: got=%b, exp=%b", $time, got_data, exp_data);
    end
  endtask  // Automatic

  task automatic check_flag_type(input logic rx_valid, input logic exp_valid, input logic rx_error,
                                 input logic exp_error);
    checks++;
    if (rx_valid !== exp_valid) begin
      errors++;
      $error("t=%0t flag mismatch (valid): got=%b, exp=%b", $time, rx_valid, exp_valid);
    end

    checks++;
    if (rx_error !== exp_error) begin
      errors++;
      $error("t=%0t flag mismatch (error): got=%b, exp=%b", $time, rx_error, exp_error);
    end
  endtask  // Automatic

  task automatic check_flag_len(input int len);  // Reads live DUT signals, prevents stale args
    checks++;
    repeat (len) @(posedge clk);
    #1;  // let the DUT's nonblocking updates settle before sampling
    if (rx_valid || rx_error) begin
      errors++;
      $error("t=%0t flag held longer than %0d cycle(s)", $time, len);
    end
  endtask  // Automatic

  task automatic do_verdict();
    @(posedge clk);
    if (checks != frames_sent * 3 + valid_frames) begin
      $fatal(1, "TB UNDER-RAN: %0d checks, expected %0d", checks, frames_sent * 3 + valid_frames);
    end else if (errors == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, errors);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    end
    $finish;
  endtask  // Automatic

  // Exhaustive value (valid + corrupt) and randomized-corrupt sweep
  task automatic run_suite();
    for (int i = 0; i < 2; i++) begin
      for (int j = 0; j < (2 ** DataBits); j++) begin
        exp_data = 8'(j);
        exp_corrupt = 1'(i);
        send_data(exp_data, exp_corrupt);
      end
    end

    for (int j = 0; j < (2 ** DataBits); j++) begin
      exp_data = 8'(j);
      exp_corrupt = 1'($urandom);
      send_data(exp_data, exp_corrupt);
    end
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, uart_rx_tb);
    do_reset();

    // Normal baud
    tx_bit = ClksPerBit;
    run_suite();

    // TX baud +2% (shorter bit)
    tx_bit = ClksPerBitFast;
    run_suite();

    // TX baud -2% (longer bit)
    tx_bit = ClksPerBitSlow;
    run_suite();

    @(posedge clk);

    do_verdict();
  end

  assign exp_valid = ~exp_corrupt;
  assign exp_error = exp_corrupt;

  always @(posedge rx_valid, posedge rx_error) begin
    check_flag_type(rx_valid, exp_valid, rx_error, exp_error);
    check_flag_len(1);
  end

  always @(posedge rx_valid) begin
    check_data(rx_data, exp_data);
  end

  always @(posedge clk)
    if (rst_n && rx_valid && rx_error) begin
      errors++;
      $error("t=%0t rx_valid and rx_error both high", $time);
    end

endmodule
