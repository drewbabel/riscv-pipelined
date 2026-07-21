module muldiv
  import muldiv_pkg::*;
#(
    parameter int XLEN = 32
) (
    input  logic                              clk,
    input  logic                              core_en,
    input  logic                              rst_n,
    input  logic                              start,
    input  muldiv_pkg::muldiv_op_e            op,
    input  logic                   [XLEN-1:0] a,        // forwarded rs1
    input  logic                   [XLEN-1:0] b,        // forwarded rs2
    output logic                   [XLEN-1:0] result,
    output logic                              busy,     // stall driver
    output logic                              done      // result valid
);

  typedef enum logic [1:0] {
    IDLE,
    EXEC,
    DONE
  } state_t;
  state_t state, next_state;

  logic                   [      XLEN-1:0] stored_a;
  logic                   [      XLEN-1:0] stored_b;
  muldiv_pkg::muldiv_op_e                  stored_op;
  logic                   [$clog2(XLEN):0] cycle_count;

  logic                   [      XLEN-1:0] quotient;
  logic                   [      XLEN-1:0] remainder;
  logic                   [      XLEN-1:0] div_n;
  logic                   [      XLEN-1:0] div_d;
  logic                                    quot_neg;
  logic                                    rem_neg;

  // Widened high-half products
  logic                   [    2*XLEN-1:0] mulh_ss;
  logic                   [    2*XLEN-1:0] mulh_su;
  logic                   [    2*XLEN-1:0] mulh_uu;
  assign mulh_ss = {{XLEN{stored_a[XLEN-1]}}, stored_a} * {{XLEN{stored_b[XLEN-1]}}, stored_b};
  assign mulh_su = {{XLEN{stored_a[XLEN-1]}}, stored_a} * {{XLEN{1'b0}}, stored_b};
  assign mulh_uu = {{XLEN{1'b0}}, stored_a} * {{XLEN{1'b0}}, stored_b};

  logic op_signed;
  assign op_signed = (op == MD_DIV) || (op == MD_REM);

  logic is_div;
  assign is_div = (stored_op == MD_DIV) || (stored_op == MD_DIVU);

  logic overflow;
  assign overflow = ((stored_op == MD_DIV) || (stored_op == MD_REM)) &&
                    (stored_a == {1'b1, {(XLEN - 1) {1'b0}}}) && (&stored_b);

  logic op_complete;
  always_comb begin
    case (stored_op)
      MD_MUL, MD_MULH, MD_MULHSU, MD_MULHU: op_complete = 1'b1;
      default:
      op_complete = (stored_b == '0) || overflow || (cycle_count == ($bits(cycle_count))'(XLEN));
    endcase
  end

  logic [XLEN-1:0] q_signed;
  logic [XLEN-1:0] r_signed;
  assign q_signed = quot_neg ? -quotient : quotient;
  assign r_signed = rem_neg ? -remainder : remainder;

  logic [XLEN-1:0] div_result;
  always_comb begin
    if (stored_b == '0) div_result = is_div ? '1 : stored_a;
    else if (overflow) div_result = is_div ? stored_a : '0;
    else div_result = is_div ? q_signed : r_signed;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state       <= IDLE;
      result      <= '0;
      busy        <= 1'b0;
      done        <= 1'b0;
      cycle_count <= '0;
      quotient    <= '0;
      remainder   <= '0;
    end else if (core_en) begin
      state <= next_state;
      case (state)
        IDLE: begin
          busy <= 1'b0;
          done <= 1'b0;
          if (start) begin
            stored_a    <= a;
            stored_b    <= b;
            stored_op   <= op;
            busy        <= 1'b1;
            cycle_count <= '0;
            quotient    <= '0;
            remainder   <= '0;
            div_n       <= (op_signed && a[XLEN-1]) ? -a : a;
            div_d       <= (op_signed && b[XLEN-1]) ? -b : b;
            quot_neg    <= op_signed && (a[XLEN-1] ^ b[XLEN-1]);
            rem_neg     <= op_signed && a[XLEN-1];
          end
        end
        EXEC: begin
          case (stored_op)
            MD_MUL:    result <= stored_a * stored_b;
            MD_MULH:   result <= mulh_ss[2*XLEN-1:XLEN];
            MD_MULHSU: result <= mulh_su[2*XLEN-1:XLEN];
            MD_MULHU:  result <= mulh_uu[2*XLEN-1:XLEN];
            default:
            if (op_complete) result <= div_result;
            else begin
              cycle_count <= cycle_count + 1'b1;
              div_n       <= div_n << 1;
              if ({remainder[XLEN-2:0], div_n[XLEN-1]} >= div_d) begin
                remainder <= {remainder[XLEN-2:0], div_n[XLEN-1]} - div_d;
                quotient  <= {quotient[XLEN-2:0], 1'b1};
              end else begin
                remainder <= {remainder[XLEN-2:0], div_n[XLEN-1]};
                quotient  <= {quotient[XLEN-2:0], 1'b0};
              end
            end
          endcase
          if (op_complete) begin
            done <= 1'b1;
            busy <= 1'b0;
          end
        end
        DONE: done <= 1'b0;
        default: ;
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = EXEC;
      EXEC: if (op_complete) next_state = DONE;
      DONE: next_state = IDLE;
      default: ;
    endcase
  end

endmodule
