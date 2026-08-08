module boot_loader_tb ();

  int checks = 0;
  int errors = 0;

  localparam int XLEN = 32;
  localparam int Depth = 20000;
  localparam int SmallDepth = 32;

  logic            clk = 1'b0;
  logic            rst_n;
  logic            rx_valid;
  logic [     7:0] rx_data;
  logic            we;
  logic [XLEN-1:0] waddr;
  logic [XLEN-1:0] wdata;
  logic            loading;

  logic            small_we;
  logic [XLEN-1:0] small_waddr;
  logic [XLEN-1:0] small_wdata;
  logic            small_loading;
  logic [XLEN-1:0] small_idx = '0;

  logic [    31:0] prog             [];
  logic [XLEN-1:0] write_idx = '0;
  logic [XLEN-1:0] data_cnt;

  always #5 clk = ~clk;

  boot_loader #(
      .XLEN (XLEN),
      .DEPTH(Depth)
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
    send_word(data_cnt);
    for (int i = 0; i < prog.size(); i++) send_word(prog[i]);
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, boot_loader_tb);
    do_reset();

    // Past old cap
    data_cnt = 32'd16400;
    prog = new[data_cnt];

    prog[0] = 32'hAABBCCDD;
    for (int i = 1; i < int'(data_cnt); i++) begin
      prog[i] = $urandom();
    end
    prog[16383] = 32'h1234_5678;
    prog[16384] = 32'h9ABC_DEF0;

    load_data();

    repeat (2) @(posedge clk);
    check("loading", {31'd0, loading}, 32'd0);
    check("write_idx", write_idx, data_cnt);
    check("small_loading", {31'd0, small_loading}, 32'd0);
    check("small_idx", small_idx, XLEN'(SmallDepth));
    verdict();
  end

  always @(posedge clk) begin
    if (we) begin
      check("waddr", waddr, write_idx * 4);
      check("wdata", wdata, prog[write_idx]);
      write_idx++;
    end
    if (small_we) begin
      check("small_waddr", small_waddr, small_idx * 4);
      check("small_wdata", small_wdata, prog[small_idx]);
      small_idx++;
    end
  end

  // Depth clamps load
  boot_loader #(
      .XLEN (XLEN),
      .DEPTH(SmallDepth)
  ) dut_small (
      .clk     (clk),
      .core_en (1'b1),
      .rst_n   (rst_n),
      .rx_valid(rx_valid),
      .rx_data (rx_data),
      .we      (small_we),
      .waddr   (small_waddr),
      .wdata   (small_wdata),
      .loading (small_loading)
  );

endmodule
