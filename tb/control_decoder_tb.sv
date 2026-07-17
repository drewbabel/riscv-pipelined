module control_decoder_tb ();

  int         checks = 0;
  int         errors = 0;

  logic [6:0] op;
  logic       reg_write;
  logic [2:0] imm_src;
  logic [1:0] alu_a_src;
  logic       pc_target_src;
  logic       alu_src;
  logic       mem_write;
  logic [1:0] result_src;
  logic       branch;
  logic       jump;
  logic [1:0] alu_op;

  localparam logic [6:0] OpcodeOp = 7'b0110011;
  localparam logic [6:0] OpcodeOpImm = 7'b0010011;
  localparam logic [6:0] OpcodeLoad = 7'b0000011;
  localparam logic [6:0] OpcodeStore = 7'b0100011;
  localparam logic [6:0] OpcodeBranch = 7'b1100011;
  localparam logic [6:0] OpcodeJal = 7'b1101111;
  localparam logic [6:0] OpcodeJalr = 7'b1100111;
  localparam logic [6:0] OpcodeLui = 7'b0110111;
  localparam logic [6:0] OpcodeAuipc = 7'b0010111;

  localparam logic [2:0] ImmI = 3'd0;
  localparam logic [2:0] ImmS = 3'd1;
  localparam logic [2:0] ImmB = 3'd2;
  localparam logic [2:0] ImmU = 3'd3;
  localparam logic [2:0] ImmJ = 3'd4;

  localparam logic [1:0] SrcARs1 = 2'd0;
  localparam logic [1:0] SrcAPc = 2'd1;
  localparam logic [1:0] SrcAZero = 2'd2;

  localparam logic [1:0] ResAlu = 2'd0;
  localparam logic [1:0] ResMem = 2'd1;
  localparam logic [1:0] ResPc4 = 2'd2;

  localparam logic [1:0] AluAdd = 2'b00;
  localparam logic [1:0] AluBranch = 2'b01;
  localparam logic [1:0] AluFunct = 2'b10;

  control_decoder dut (
      .op           (op),
      .reg_write    (reg_write),
      .imm_src      (imm_src),
      .alu_a_src    (alu_a_src),
      .pc_target_src(pc_target_src),
      .alu_src      (alu_src),
      .mem_write    (mem_write),
      .result_src   (result_src),
      .branch       (branch),
      .jump         (jump),
      .alu_op       (alu_op)
  );

  task automatic check1(input string name, input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("%s mismatch: got %b, exp %b", name, got, exp);
    end
  endtask

  task automatic check2(input string name, input logic [1:0] got, input logic [1:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("%s mismatch: got %b, exp %b", name, got, exp);
    end
  endtask

  task automatic check3(input string name, input logic [2:0] got, input logic [2:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("%s mismatch: got %b, exp %b", name, got, exp);
    end
  endtask

  task automatic verdict();
    if (errors == 0) $display("PASS: %0d checks, %0d mismatches", checks, errors);
    else $fatal(1, "FAIL: %0d mismatches, %0d checks", errors, checks);
    $finish;
  endtask

  initial begin
    $dumpfile("control_decoder_tb.vcd");
    $dumpvars(0, control_decoder_tb);

    // R-type
    op = OpcodeOp;
    #1;
    check1("op reg_write", reg_write, 1'b1);
    check1("op alu_src", alu_src, 1'b0);
    check1("op mem_write", mem_write, 1'b0);
    check2("op result_src", result_src, ResAlu);
    check1("op branch", branch, 1'b0);
    check1("op jump", jump, 1'b0);
    check2("op alu_op", alu_op, AluFunct);
    check2("op alu_a_src", alu_a_src, SrcARs1);
    check1("op pc_target_src", pc_target_src, 1'b0);

    // I-type ALU
    op = OpcodeOpImm;
    #1;
    check1("opimm reg_write", reg_write, 1'b1);
    check3("opimm imm_src", imm_src, ImmI);
    check1("opimm alu_src", alu_src, 1'b1);
    check1("opimm mem_write", mem_write, 1'b0);
    check2("opimm result_src", result_src, ResAlu);
    check1("opimm branch", branch, 1'b0);
    check1("opimm jump", jump, 1'b0);
    check2("opimm alu_op", alu_op, AluFunct);
    check2("opimm alu_a_src", alu_a_src, SrcARs1);
    check1("opimm pc_target_src", pc_target_src, 1'b0);

    // Load
    op = OpcodeLoad;
    #1;
    check1("load reg_write", reg_write, 1'b1);
    check3("load imm_src", imm_src, ImmI);
    check1("load alu_src", alu_src, 1'b1);
    check1("load mem_write", mem_write, 1'b0);
    check2("load result_src", result_src, ResMem);
    check1("load branch", branch, 1'b0);
    check1("load jump", jump, 1'b0);
    check2("load alu_op", alu_op, AluAdd);
    check2("load alu_a_src", alu_a_src, SrcARs1);
    check1("load pc_target_src", pc_target_src, 1'b0);

    // Store
    op = OpcodeStore;
    #1;
    check1("store reg_write", reg_write, 1'b0);
    check3("store imm_src", imm_src, ImmS);
    check1("store alu_src", alu_src, 1'b1);
    check1("store mem_write", mem_write, 1'b1);
    check1("store branch", branch, 1'b0);
    check1("store jump", jump, 1'b0);
    check2("store alu_op", alu_op, AluAdd);
    check2("store alu_a_src", alu_a_src, SrcARs1);
    check1("store pc_target_src", pc_target_src, 1'b0);

    // Branch
    op = OpcodeBranch;
    #1;
    check1("branch reg_write", reg_write, 1'b0);
    check3("branch imm_src", imm_src, ImmB);
    check1("branch alu_src", alu_src, 1'b0);
    check1("branch mem_write", mem_write, 1'b0);
    check1("branch branch", branch, 1'b1);
    check1("branch jump", jump, 1'b0);
    check2("branch alu_op", alu_op, AluBranch);
    check2("branch alu_a_src", alu_a_src, SrcARs1);
    check1("branch pc_target_src", pc_target_src, 1'b0);

    // jal
    op = OpcodeJal;
    #1;
    check1("jal reg_write", reg_write, 1'b1);
    check3("jal imm_src", imm_src, ImmJ);
    check1("jal mem_write", mem_write, 1'b0);
    check2("jal result_src", result_src, ResPc4);
    check1("jal branch", branch, 1'b0);
    check1("jal jump", jump, 1'b1);
    check2("jal alu_a_src", alu_a_src, SrcARs1);
    check1("jal pc_target_src", pc_target_src, 1'b0);

    // jalr
    op = OpcodeJalr;
    #1;
    check1("jalr reg_write", reg_write, 1'b1);
    check3("jalr imm_src", imm_src, ImmI);
    check1("jalr alu_src", alu_src, 1'b1);
    check1("jalr mem_write", mem_write, 1'b0);
    check2("jalr result_src", result_src, ResPc4);
    check1("jalr branch", branch, 1'b0);
    check1("jalr jump", jump, 1'b1);
    check2("jalr alu_op", alu_op, AluAdd);
    check2("jalr alu_a_src", alu_a_src, SrcARs1);
    check1("jalr pc_target_src", pc_target_src, 1'b1);

    // lui
    op = OpcodeLui;
    #1;
    check1("lui reg_write", reg_write, 1'b1);
    check3("lui imm_src", imm_src, ImmU);
    check1("lui alu_src", alu_src, 1'b1);
    check1("lui mem_write", mem_write, 1'b0);
    check2("lui result_src", result_src, ResAlu);
    check1("lui branch", branch, 1'b0);
    check1("lui jump", jump, 1'b0);
    check2("lui alu_op", alu_op, AluAdd);
    check2("lui alu_a_src", alu_a_src, SrcAZero);
    check1("lui pc_target_src", pc_target_src, 1'b0);

    // auipc
    op = OpcodeAuipc;
    #1;
    check1("auipc reg_write", reg_write, 1'b1);
    check3("auipc imm_src", imm_src, ImmU);
    check1("auipc alu_src", alu_src, 1'b1);
    check1("auipc mem_write", mem_write, 1'b0);
    check2("auipc result_src", result_src, ResAlu);
    check1("auipc branch", branch, 1'b0);
    check1("auipc jump", jump, 1'b0);
    check2("auipc alu_op", alu_op, AluAdd);
    check2("auipc alu_a_src", alu_a_src, SrcAPc);
    check1("auipc pc_target_src", pc_target_src, 1'b0);

    // Illegal opcode
    op = 7'b1111111;
    #1;
    check1("illegal reg_write", reg_write, 1'b0);
    check1("illegal mem_write", mem_write, 1'b0);

    verdict();
  end

endmodule
