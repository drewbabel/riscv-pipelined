package muldiv_pkg;

  // value equals funct3
  typedef enum logic [2:0] {
    MD_MUL,     // low product
    MD_MULH,    // high signed
    MD_MULHSU,  // high signed unsigned
    MD_MULHU,   // high unsigned
    MD_DIV,     // signed quotient
    MD_DIVU,    // unsigned quotient
    MD_REM,     // signed remainder
    MD_REMU     // unsigned remainder
  } muldiv_op_e;

  // RV32M funct7
  localparam logic [6:0] Funct7MulDiv = 7'b0000001;

endpackage
