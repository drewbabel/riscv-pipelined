module boot_loader_tb ();

  int checks = 0;
  int errors = 0;

  localparam int XLEN = 32;

  logic            clk = 1'b0;
  logic            rst_n;
  logic            rx_valid;
  logic [     7:0] rx_data;
  logic            we;
  logic [XLEN-1:0] waddr;
  logic [XLEN-1:0] wdata;
  logic            loading;

  logic [    31:0] prog             [];
  logic [     7:0] write_idx = 8'd0;
  logic [     7:0] data_cnt;

  always #5 clk = ~clk;

  boot_loader #(
      .XLEN(XLEN)
  ) dut (
      .clk     (clk),
      .core_en (1'b1),
      .rst_n   (rst_n),
      .rx_valid(rx_valid),
      .rx_data (rx_data),
      .we      (we),
      .waddr   (waddr),
      .wdata   (wdata),
      .loading (loading)
  );

  task automatic do_reset();
    rst_n    = 0;
    rx_valid = 0;
    rx_data  = '0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask  // Automatic

  task automatic check(input string name, input logic [XLEN-1:0] got, input logic [XLEN-1:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s got %08x exp %08x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic verdict();
    @(posedge clk);
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask  // Automatic

  task automatic send_byte(input logic [7:0] data);
    rx_data = data;
    #1 rx_valid = 1'b1;
    @(posedge clk);
    #1 rx_valid = 1'b0;
  endtask  // Automatic

  task automatic send_word(input logic [31:0] w);
    for (int j = 0; j < XLEN; j += 8) send_byte(w[j+:8]);
  endtask  // Automatic

  task automatic load_data();
    send_word({24'd0, data_cnt});
    foreach (prog[i]) send_word(prog[i]);
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, boot_loader_tb);
    do_reset();

    data_cnt = 8'd50;
    prog = new[{24'd0, data_cnt}];

    prog[0] = 32'hAABBCCDD;
    for (int i = 1; i < 50; i++) begin
      prog[i] = $urandom();
    end

    load_data();

    repeat (2) @(posedge clk);
    check("loading", {31'd0, loading}, 32'd0);
    check("write_idx", {24'd0, write_idx}, {24'd0, data_cnt});
    verdict();
  end

  always @(posedge clk) begin
    if (we) begin
      check("waddr", waddr, write_idx * 4);
      check("wdata", wdata, prog[write_idx]);
      write_idx++;
    end
  end

endmodule
