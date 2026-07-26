module btb_tb;

  import bp_pkg::*;

  localparam int Xlen = 32;
  localparam int TagLen = Xlen - 2 - BtbIdxLen;

  logic clk;
  logic core_en;
  logic rst_n;
  logic [Xlen-1:0] lookup_pc;
  logic hit;
  logic [Xlen-1:0] target;
  logic is_cond;
  logic update_valid;
  logic [Xlen-1:0] update_pc;
  logic [Xlen-1:0] update_target;
  logic update_is_cond;

  int checks = 0;
  int errors = 0;

  // Reference model
  logic ref_valid[BtbDepth];
  logic [TagLen-1:0] ref_tag[BtbDepth];
  logic [Xlen-1:0] ref_targ[BtbDepth];
  logic ref_cond[BtbDepth];

  always #5 clk = ~clk;

  btb #(
      .XLEN(Xlen)
  ) dut (
      .clk           (clk),
      .core_en       (core_en),
      .rst_n         (rst_n),
      .lookup_pc     (lookup_pc),
      .hit           (hit),
      .target        (target),
      .is_cond       (is_cond),
      .update_valid  (update_valid),
      .update_pc     (update_pc),
      .update_target (update_target),
      .update_is_cond(update_is_cond)
  );

  task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin
      $error("%s: got %08x exp %08x", name, got, exp);
      errors++;
    end
  endtask  // Automatic

  task automatic do_reset();
    rst_n = 1'b0;
    @(posedge clk);
    @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    for (int i = 0; i < BtbDepth; i++) ref_valid[i] = 1'b0;
  endtask  // Automatic

  task automatic install(input logic [Xlen-1:0] pc, input logic [Xlen-1:0] tgt, input logic c);
    #1;
    update_valid   = 1'b1;
    update_pc      = pc;
    update_target  = tgt;
    update_is_cond = c;
    @(posedge clk);
    ref_valid[pc[2+:BtbIdxLen]] = 1'b1;
    ref_tag[pc[2+:BtbIdxLen]]   = pc[BtbIdxLen+2+:TagLen];
    ref_targ[pc[2+:BtbIdxLen]]  = tgt;
    ref_cond[pc[2+:BtbIdxLen]]  = c;
    #1;
    update_valid = 1'b0;
    @(posedge clk);
  endtask  // Automatic

  task automatic probe(input logic [Xlen-1:0] pc);
    logic exp_hit;
    #1;
    lookup_pc = pc;
    #1;
    exp_hit = ref_valid[pc[2+:BtbIdxLen]] && (ref_tag[pc[2+:BtbIdxLen]] == pc[BtbIdxLen+2+:TagLen]);
    check("hit", 32'(hit), 32'(exp_hit));
    if (exp_hit) begin
      check("target", target, ref_targ[pc[2+:BtbIdxLen]]);
      check("is_cond", 32'(is_cond), 32'(ref_cond[pc[2+:BtbIdxLen]]));
    end
  endtask  // Automatic

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, btb_tb);

    clk = 1'b0;
    core_en = 1'b1;
    rst_n = 1'b1;
    lookup_pc = '0;
    update_valid = 1'b0;
    update_pc = '0;
    update_target = '0;
    update_is_cond = 1'b0;

    do_reset();

    // Cold miss
    probe(32'h0000_0040);

    // Install then hit
    install(32'h0000_0040, 32'h0000_1234, 1'b1);
    probe(32'h0000_0040);

    // Tag miss
    probe(32'h0000_0440);

    // Aliasing replace
    install(32'h0000_0440, 32'h0000_5678, 1'b0);
    probe(32'h0000_0440);
    probe(32'h0000_0040);

    // Other set
    install(32'h0000_0080, 32'h0000_9ABC, 1'b1);
    probe(32'h0000_0080);
    probe(32'h0000_0440);

    // Reset clears
    do_reset();
    probe(32'h0000_0440);
    probe(32'h0000_0080);

    // Random sweep
    for (int i = 0; i < 400; i++) begin
      install({16'b0, 16'($urandom)} & 32'hFFFF_FFFC, $urandom, 1'($urandom));
      probe({16'b0, 16'($urandom)} & 32'hFFFF_FFFC);
    end

    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  end

endmodule
