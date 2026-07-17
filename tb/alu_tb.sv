module alu_tb
  import alu_pkg::*;
();

  int checks = 0;
  int error_count = 0;

  localparam int XLEN = 32;
  localparam int SHAMT = $clog2(XLEN);  // Shift-amount width

  logic [XLEN-1:0] a;
  logic [XLEN-1:0] b;
  alu_pkg::alu_op_e alu_op;
  logic [XLEN-1:0] result;
  logic zero;
  logic lt;
  logic ltu;

  alu #(
      .XLEN(XLEN)
  ) dut (
      .a(a),
      .b(b),
      .alu_op(alu_op),
      .result(result),
      .zero(zero),
      .lt(lt),
      .ltu(ltu)
  );

  // Golden reference
  function automatic logic [XLEN-1:0] alu_ref(input logic [XLEN-1:0] a, input logic [XLEN-1:0] b,
                                              input alu_pkg::alu_op_e op);
    case (op)
      ALU_ADD:  return a + b;
      ALU_SUB:  return a - b;
      ALU_SLL:  return a << b[SHAMT-1:0];
      ALU_SLT:  return ($signed(a) < $signed(b)) ? 1 : 0;
      ALU_SLTU: return (a < b) ? 1 : 0;
      ALU_XOR:  return a ^ b;
      ALU_SRL:  return a >> b[SHAMT-1:0];
      ALU_SRA:  return $signed(a) >>> b[SHAMT-1:0];
      ALU_OR:   return a | b;
      ALU_AND:  return a & b;
      default:  return '0;
    endcase
  endfunction

  function automatic logic zero_ref(input logic [XLEN-1:0] value);
    return (value == '0);
  endfunction

  function automatic logic lt_ref(input logic [XLEN-1:0] a, input logic [XLEN-1:0] b,
                                  input alu_pkg::alu_op_e op, input logic [XLEN-1:0] result_ref);
    return (op == ALU_SLT) ? result_ref[0] : ($signed(a) < $signed(b));
  endfunction

  function automatic logic ltu_ref(input logic [XLEN-1:0] a, input logic [XLEN-1:0] b,
                                   input alu_pkg::alu_op_e op, input logic [XLEN-1:0] result_ref);
    return (op == ALU_SLTU) ? result_ref[0] : (a < b);
  endfunction

  task automatic check_flag(input string flag_name, input logic [XLEN-1:0] got,
                            input logic [XLEN-1:0] exp);
    checks++;
    if (got !== exp) begin
      error_count++;
      $display("ALU %s mismatch op=%0d a=%h b=%h exp=%h got=%h", flag_name, alu_op, a, b, exp, got);
    end
  endtask

  task automatic check_case(input logic [XLEN-1:0] a_in, input logic [XLEN-1:0] b_in,
                            input alu_pkg::alu_op_e op_in);
    logic [XLEN-1:0] result_ref;
    logic zero_exp;
    logic lt_ref_val;
    logic ltu_ref_val;

    a = a_in;
    b = b_in;
    alu_op = op_in;
    #1;  // let DUT settle before sampling outputs

    result_ref = alu_ref(a_in, b_in, op_in);
    zero_exp = zero_ref(result_ref);
    lt_ref_val = lt_ref(a_in, b_in, op_in, result_ref);
    ltu_ref_val = ltu_ref(a_in, b_in, op_in, result_ref);

    check_flag("result", result, result_ref);
    check_flag("zero", {{(XLEN - 1) {1'b0}}, zero}, {{(XLEN - 1) {1'b0}}, zero_exp});
    check_flag("lt", {{(XLEN - 1) {1'b0}}, lt}, {{(XLEN - 1) {1'b0}}, lt_ref_val});
    check_flag("ltu", {{(XLEN - 1) {1'b0}}, ltu}, {{(XLEN - 1) {1'b0}}, ltu_ref_val});
  endtask

  task automatic verdict();
    if (error_count == 0) begin
      $display("PASS: %0d checks, %0d mismatches", checks, error_count);
    end else begin
      $fatal(1, "FAIL: %0d mismatches, %0d checks", error_count, checks);
    end
    $finish;
  endtask

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, alu_tb);

    // Directed corner cases
    check_case(32'h0000_0000, 32'h0000_0000, ALU_ADD);
    check_case(32'hFFFF_FFFF, 32'hFFFF_FFFF, ALU_AND);

    check_case(32'h1234_5678, 32'h1234_5678, ALU_SUB);
    check_case(32'h1234_5678, 32'h0000_0001, ALU_ADD);

    check_case(32'h0000_0001, 32'h0000_0000, ALU_SLL);
    check_case(32'h1234_5678, 32'h0000_001F, ALU_SLL);
    check_case(32'h1234_5678, 32'hFFFF_FF05, ALU_SLL);

    check_case(32'h8000_0001, 32'h0000_0004, ALU_SRA);
    check_case(32'h8000_0001, 32'h0000_0004, ALU_SRL);

    check_case(32'h7FFF_FFFF, 32'h8000_0000, ALU_SLT);
    check_case(32'h7FFF_FFFF, 32'h8000_0000, ALU_SLTU);

    check_case(32'h1234_5678, 32'h0000_0000, ALU_OR);
    check_case(32'hFFFF_FFFF, 32'h0000_0000, ALU_OR);

    // Randomized sweep
    repeat (3000) begin
      check_case($urandom, $urandom, alu_pkg::alu_op_e'($urandom_range(0, 9)));
    end

    verdict();
  end

endmodule
