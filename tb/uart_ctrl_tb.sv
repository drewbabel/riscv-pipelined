module uart_ctrl_tb ();

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;

  localparam logic [Xlen-1:0] TxDataAddr = 32'h0400_0000;
  localparam logic [Xlen-1:0] StatusAddr = 32'h0400_0004;
  localparam logic [Xlen-1:0] RxDataAddr = 32'h0400_0008;
  localparam logic [Xlen-1:0] CtrlAddr = 32'h0400_000C;

  logic            clk = 1'b0;
  logic            rst_n;
  logic            sel;
  logic            req;
  logic [     3:0] wstrb;
  logic [Xlen-1:0] addr;
  logic [Xlen-1:0] wdata;
  logic [Xlen-1:0] rdata;
  logic            rx_valid;
  logic [     7:0] rx_data;
  logic            tx_ready;
  logic            tx_valid;
  logic [     7:0] tx_data;
  logic            irq;

  always #5 clk = ~clk;

  uart_ctrl #(
      .XLEN(Xlen)
  ) dut (
      .clk     (clk),
      .core_en (1'b1),
      .rst_n   (rst_n),
      .sel     (sel),
      .req     (req),
      .wstrb   (wstrb),
      .addr    (addr),
      .wdata   (wdata),
      .rdata   (rdata),
      .rx_valid(rx_valid),
      .rx_data (rx_data),
      .tx_ready(tx_ready),
      .tx_valid(tx_valid),
      .tx_data (tx_data),
      .irq     (irq)
  );

  task automatic check(input string name, input logic [Xlen-1:0] got, input logic [Xlen-1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $error("%s: got %h exp %h", name, got, exp);
    end
  endtask  // Automatic

  task automatic do_reset();
    rst_n = 1'b0;
    sel = 1'b0;
    req = 1'b0;
    wstrb = 4'h0;
    addr = '0;
    wdata = '0;
    rx_valid = 1'b0;
    rx_data = '0;
    tx_ready = 1'b1;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
  endtask  // Automatic

  task automatic bus_write(input logic [Xlen-1:0] a, input logic [Xlen-1:0] d);
    #1;
    sel   = 1'b1;
    req   = 1'b1;
    addr  = a;
    wdata = d;
    wstrb = 4'hF;
    @(posedge clk);
    #1;
    sel   = 1'b0;
    req   = 1'b0;
    wstrb = 4'h0;
  endtask  // Automatic

  task automatic bus_read(input logic [Xlen-1:0] a, output logic [Xlen-1:0] d);
    #1;
    sel   = 1'b1;
    req   = 1'b1;
    addr  = a;
    wstrb = 4'h0;
    #1;
    d = rdata;
    @(posedge clk);
    #1;
    sel = 1'b0;
    req = 1'b0;
  endtask  // Automatic

  task automatic peek(input logic [Xlen-1:0] a, output logic [Xlen-1:0] d);
    #1;
    sel   = 1'b1;
    req   = 1'b0;
    addr  = a;
    wstrb = 4'h0;
    #1;
    d   = rdata;
    sel = 1'b0;
  endtask  // Automatic

  task automatic arrive(input logic [7:0] b);
    #1;
    rx_valid = 1'b1;
    rx_data  = b;
    @(posedge clk);
    #1;
    rx_valid = 1'b0;
  endtask  // Automatic

  task automatic tx_store(input logic [7:0] b);
    #1;
    sel   = 1'b1;
    req   = 1'b1;
    addr  = TxDataAddr;
    wdata = {24'b0, b};
    wstrb = 4'hF;
    #1;
    check("tx_valid", tx_valid, 1'b1);
    check("tx_data", tx_data, {24'b0, b});
    @(posedge clk);
    #1;
    sel   = 1'b0;
    req   = 1'b0;
    wstrb = 4'h0;
    #1;
    check("tx_valid_clear", tx_valid, 1'b0);
  endtask  // Automatic

  task automatic take_during_arrival(input logic [7:0] b);
    #1;
    sel      = 1'b1;
    req      = 1'b1;
    addr     = RxDataAddr;
    wstrb    = 4'h0;
    rx_valid = 1'b1;
    rx_data  = b;
    @(posedge clk);
    #1;
    sel      = 1'b0;
    req      = 1'b0;
    rx_valid = 1'b0;
  endtask  // Automatic

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  logic [Xlen-1:0] got;

  initial begin
    $dumpfile("uart_ctrl_tb.vcd");
    $dumpvars(0, uart_ctrl_tb);

    do_reset();

    peek(StatusAddr, got);
    check("status_reset", got, 32'h1);
    check("irq_reset", irq, 1'b0);

    tx_store(8'h41);

    arrive(8'h5A);
    peek(StatusAddr, got);
    check("status_full", got, 32'h3);
    check("irq_masked", irq, 1'b0);

    bus_write(CtrlAddr, 32'h1);
    peek(CtrlAddr, got);
    check("ctrl_readback", got, 32'h1);
    check("irq_raised", irq, 1'b1);

    arrive(8'h77);
    peek(StatusAddr, got);
    check("status_overrun", got, 32'h7);

    bus_read(RxDataAddr, got);
    check("rx_byte", got, 32'h0000_005A);
    check("irq_cleared", irq, 1'b0);
    peek(StatusAddr, got);
    check("status_empty", got, 32'h1);

    arrive(8'h2B);
    peek(StatusAddr, got);
    check("status_full_again", got, 32'h3);
    bus_read(StatusAddr, got);
    check("irq_held", irq, 1'b1);
    bus_read(RxDataAddr, got);
    check("rx_byte_again", got, 32'h0000_002B);
    check("irq_cleared_again", irq, 1'b0);

    take_during_arrival(8'h99);
    peek(StatusAddr, got);
    check("status_race_full", got, 32'h3);
    bus_read(RxDataAddr, got);
    check("rx_byte_race", got, 32'h0000_0099);

    verdict();
  end

endmodule
