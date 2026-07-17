module alu_decoder_tb
  import alu_pkg::*;
();

  int                     checks = 0;
  int                     errors = 0;

  logic             [1:0] alu_op;
  logic             [2:0] funct3;
  logic                   funct7b5;
  logic                   op5;
  alu_pkg::alu_op_e       alu_ctrl;
  alu_pkg::alu_op_e       exp;
  alu_pkg::alu_op_e       got;

  localparam logic [1:0] AluOpAdd = 2'b00;
  localparam logic [1:0] AluOpBranch = 2'b01;
  localparam logic [1:0] AluOpFunct = 2'b10;

  alu_decoder dut (
      .alu_op  (alu_op),
      .funct3  (funct3),
      .funct7b5(funct7b5),
      .op5     (op5),
      .alu_ctrl(alu_ctrl)
  );

  // vector: {alu_op[1:0], funct3[2:0], funct7b5, op5, exp[3:0]}
  logic [10:0] vectors[17];

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  initial begin
    $dumpfile("alu_decoder_tb.vcd");
    $dumpvars(0, alu_decoder_tb);

    vectors[0]  = {AluOpAdd, 3'b000, 1'b0, 1'b0, ALU_ADD};  // add category
    vectors[1]  = {AluOpAdd, 3'b111, 1'b1, 1'b1, ALU_ADD};  // add category ignores funct
    vectors[2]  = {AluOpBranch, 3'b000, 1'b0, 1'b0, ALU_SUB};  // branch category
    vectors[3]  = {AluOpFunct, 3'b000, 1'b0, 1'b1, ALU_ADD};  // add r
    vectors[4]  = {AluOpFunct, 3'b000, 1'b1, 1'b1, ALU_SUB};  // sub r
    vectors[5]  = {AluOpFunct, 3'b000, 1'b1, 1'b0, ALU_ADD};  // addi bit30 set stays add
    vectors[6]  = {AluOpFunct, 3'b000, 1'b0, 1'b0, ALU_ADD};  // addi
    vectors[7]  = {AluOpFunct, 3'b001, 1'b0, 1'b1, ALU_SLL};  // sll
    vectors[8]  = {AluOpFunct, 3'b010, 1'b0, 1'b1, ALU_SLT};  // slt
    vectors[9]  = {AluOpFunct, 3'b011, 1'b0, 1'b1, ALU_SLTU};  // sltu
    vectors[10] = {AluOpFunct, 3'b100, 1'b0, 1'b1, ALU_XOR};  // xor
    vectors[11] = {AluOpFunct, 3'b110, 1'b0, 1'b1, ALU_OR};  // or
    vectors[12] = {AluOpFunct, 3'b111, 1'b0, 1'b1, ALU_AND};  // and
    vectors[13] = {AluOpFunct, 3'b101, 1'b0, 1'b1, ALU_SRL};  // srl r
    vectors[14] = {AluOpFunct, 3'b101, 1'b1, 1'b1, ALU_SRA};  // sra r
    vectors[15] = {AluOpFunct, 3'b101, 1'b0, 1'b0, ALU_SRL};  // srli
    vectors[16] = {AluOpFunct, 3'b101, 1'b1, 1'b0, ALU_SRA};  // srai stays arithmetic

    foreach (vectors[i]) begin
      alu_op   = vectors[i][10:9];
      funct3   = vectors[i][8:6];
      funct7b5 = vectors[i][5];
      op5      = vectors[i][4];
      exp      = alu_pkg::alu_op_e'(vectors[i][3:0]);
      #1;
      got = alu_ctrl;
      checks++;
      if (got !== exp) begin
        errors++;
        $display("vec %0d (alu_op=%b funct3=%b f7=%b o5=%b): got %s exp %s", i, alu_op, funct3,
                 funct7b5, op5, got.name(), exp.name());
      end
    end

    verdict();
  end

endmodule
