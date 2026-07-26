module gshare_tb;

  import bp_pkg::*;

  localparam int Xlen = 32;

  logic clk;
  logic core_en;
  logic rst_n;
  logic [Xlen-1:0] predict_pc;
  logic predict_taken;
  logic [GhistLen-1:0] predict_index;
  logic update_valid;
  logic update_taken;
  logic [GhistLen-1:0] update_index;

  int checks = 0;
  int errors = 0;

  // Reference model
  logic [GhistLen-1:0] ref_ghr;
  logic [1:0] ref_pht[PhtDepth];

  always #5 clk = ~clk;

  gshare #(
      .XLEN(Xlen)
  ) dut (
      .clk          (clk),
      .core_en      (core_en),
      .rst_n        (rst_n),
      .predict_pc   (predict_pc),
      .predict_taken(predict_taken),
      .predict_index(predict_index),
      .update_valid (update_valid),
      .update_taken (update_taken),
      .update_index (update_index)
  );

  task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s: got %0d exp %0d", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic do_reset();
    rst_n = 1'b0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
  endtask  // Automatic

  task automatic step(input logic uv, input logic ut, input logic [GhistLen-1:0] ui);
    #1;
    update_valid = uv;
    update_taken = ut;
    update_index = ui;
    @(posedge clk);
    if (uv) begin
      if (ut) begin
        if (ref_pht[ui] != 2'b11) ref_pht[ui] = ref_pht[ui] + 1;
      end else begin
        if (ref_pht[ui] != 2'b00) ref_pht[ui] = ref_pht[ui] - 1;
      end
      ref_ghr = {ref_ghr[GhistLen-2:0], ut};
    end
    #1;
    check("ghr", 32'(ref_ghr), 32'(dut.ghr));
    check("pht entry", 32'(ref_pht[ui]), 32'(dut.pht[ui]));
  endtask  // Automatic

  task automatic check_lookup(input logic [Xlen-1:0] pc);
    #1;
    predict_pc = pc;
    #1;
    check("index", 32'(predict_index), 32'(pc[GhistLen+1:2] ^ ref_ghr));
    check("taken", 32'(predict_taken), 32'(ref_pht[predict_index][1]));
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, gshare_tb);

    clk = 1'b0;
    core_en = 1'b1;
    rst_n = 1'b1;
    predict_pc = '0;
    update_valid = 1'b0;
    update_taken = 1'b0;
    update_index = '0;

    ref_ghr = '0;
    for (int i = 0; i < PhtDepth; i++) ref_pht[i] = 2'b01;

    do_reset();

    // Cold state
    check_lookup(32'h0000_0000);
    check("cold not taken", 32'(predict_taken), 32'd0);

    // Saturate up
    for (int i = 0; i < 6; i++) step(1'b1, 1'b1, 10'd5);
    check("saturated high", 32'(dut.pht[10'd5]), 32'd3);

    // Saturate down
    for (int i = 0; i < 6; i++) step(1'b1, 1'b0, 10'd5);
    check("saturated low", 32'(dut.pht[10'd5]), 32'd0);

    // Held update
    step(1'b0, 1'b1, 10'd5);

    // Random sweep
    for (int i = 0; i < 400; i++) begin
      step(1'($urandom), 1'($urandom), GhistLen'($urandom));
      check_lookup({20'b0, 12'($urandom)});
    end

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

endmodule
