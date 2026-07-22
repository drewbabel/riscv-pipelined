module muldiv_formal
  import muldiv_pkg::*;
();

  localparam int XLEN = 32;

  logic                              clk;
  logic                              core_en;
  logic                              rst_n;
  logic                              start;
  muldiv_pkg::muldiv_op_e            op;
  logic                   [XLEN-1:0] a;
  logic                   [XLEN-1:0] b;
  logic                   [XLEN-1:0] result;
  logic                              busy;
  logic                              done;

  muldiv #(
      .XLEN(XLEN)
  ) dut (
      .clk    (clk),
      .core_en(core_en),
      .rst_n  (rst_n),
      .start  (start),
      .op     (op),
      .a      (a),
      .b      (b),
      .result (result),
      .busy   (busy),
      .done   (done)
  );

  // reset cycle 0, one-shot start cycle 1
  logic [7:0] t = 8'd0;
  initial assume (t == 8'd0);
  always @(posedge clk) t <= t + 8'd1;
  assign rst_n   = (t != 8'd0);
  assign core_en = 1'b1;
  assign start   = (t == 8'd1);

  // capture the accepted operands
  muldiv_pkg::muldiv_op_e            ref_op;
  logic                   [XLEN-1:0] ref_a;
  logic                   [XLEN-1:0] ref_b;
  always @(posedge clk)
    if (start && rst_n) begin
      ref_op <= op;
      ref_a  <= a;
      ref_b  <= b;
    end

  // golden high and low products from the spec
  logic signed [  XLEN-1:0] sa;
  logic signed [  XLEN-1:0] sb;
  logic        [2*XLEN-1:0] prod_ss;
  logic        [2*XLEN-1:0] prod_su;
  logic        [2*XLEN-1:0] prod_uu;
  assign sa      = ref_a;
  assign sb      = ref_b;
  assign prod_ss = $signed(64'(sa)) * $signed(64'(sb));
  assign prod_su = $signed(64'(sa)) * $signed({32'b0, ref_b});
  assign prod_uu = {32'b0, ref_a} * {32'b0, ref_b};

  logic [XLEN-1:0] mul_exp;
  always_comb begin
    case (ref_op)
      MD_MUL:    mul_exp = ref_a * ref_b;
      MD_MULH:   mul_exp = prod_ss[2*XLEN-1:XLEN];
      MD_MULHSU: mul_exp = prod_su[2*XLEN-1:XLEN];
      MD_MULHU:  mul_exp = prod_uu[2*XLEN-1:XLEN];
      default:   mul_exp = 'x;
    endcase
  end

  logic [XLEN-1:0] int_min;
  assign int_min = {1'b1, {(XLEN - 1) {1'b0}}};

  logic overflow;
  assign overflow = (ref_a == int_min) && (&ref_b);

  logic is_mul;
  assign is_mul = (ref_op == MD_MUL) || (ref_op == MD_MULH) || (ref_op == MD_MULHSU) ||
      (ref_op == MD_MULHU);

  logic f_started = 1'b0;
  always @(posedge clk)
    if (!rst_n) f_started <= 1'b0;
    else if (start) f_started <= 1'b1;

  // general divide leans on Spike, this proves multiply handshake and special cases
  always @(posedge clk)
    if (rst_n) begin
      assert (!(busy && done));
      if (f_started && done) begin
        if (is_mul) assert (result == mul_exp);
        if ((ref_op == MD_DIV) && (ref_b == '0)) assert (&result);
        if ((ref_op == MD_DIV) && overflow) assert (result == int_min);
        if ((ref_op == MD_DIVU) && (ref_b == '0)) assert (&result);
        if ((ref_op == MD_REM) && (ref_b == '0)) assert (result == ref_a);
        if ((ref_op == MD_REM) && overflow) assert (result == '0);
        if ((ref_op == MD_REMU) && (ref_b == '0)) assert (result == ref_a);
      end
    end

endmodule
