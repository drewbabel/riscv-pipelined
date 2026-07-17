module extend_tb;

  int checks = 0;
  int errors = 0;

  localparam int Xlen = 32;

  logic [    31:0] instr;
  logic [     2:0] imm_src;
  logic [Xlen-1:0] imm_ext;
  logic [Xlen-1:0] exp;

  extend #(
      .XLEN(Xlen)
  ) dut (
      .instr  (instr),
      .imm_src(imm_src),
      .imm_ext(imm_ext)
  );

  // vector: {instr[31:0], imm_src[2:0], exp[31:0]}
  logic [66:0] vectors[7];

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  initial begin
    $dumpfile("extend_tb.vcd");
    $dumpvars(0, extend_tb);

    // Golden vectors assembled with riscv64-elf-gcc (rv32i)
    vectors[0] = {32'hffc00093, 3'd0, 32'hfffffffc};  // I neg addi -4
    vectors[1] = {32'h00500113, 3'd0, 32'h00000005};  // I pos addi 5
    vectors[2] = {32'hfe322c23, 3'd1, 32'hfffffff8};  // S neg sw -8
    vectors[3] = {32'hfe6288e3, 3'd2, 32'hfffffff0};  // B neg beq -16
    vectors[4] = {32'h123453b7, 3'd3, 32'h12345000};  // U lui 0x12345
    vectors[5] = {32'h0100046f, 3'd4, 32'h00000010};  // J pos jal +16
    vectors[6] = {32'hff9ff4ef, 3'd4, 32'hfffffff8};  // J neg jal -8

    foreach (vectors[i]) begin
      instr   = vectors[i][66:35];
      imm_src = vectors[i][34:32];
      exp     = vectors[i][31:0];
      #1;
      checks++;
      if (imm_ext !== exp) begin
        errors++;
        $error("vec %0d instr=%h: got %h exp %h", i, instr, imm_ext, exp);
      end
    end

    verdict();
  end

endmodule
