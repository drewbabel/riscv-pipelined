package opcode_pkg;

  // RV32I base opcodes
  localparam logic [6:0] OpcodeOp = 7'b0110011;
  localparam logic [6:0] OpcodeOpImm = 7'b0010011;
  localparam logic [6:0] OpcodeLoad = 7'b0000011;
  localparam logic [6:0] OpcodeStore = 7'b0100011;
  localparam logic [6:0] OpcodeBranch = 7'b1100011;
  localparam logic [6:0] OpcodeJal = 7'b1101111;
  localparam logic [6:0] OpcodeJalr = 7'b1100111;
  localparam logic [6:0] OpcodeLui = 7'b0110111;
  localparam logic [6:0] OpcodeAuipc = 7'b0010111;
  localparam logic [6:0] OpcodeMiscMem = 7'b0001111;
  localparam logic [6:0] OpcodeSystem = 7'b1110011;

endpackage
