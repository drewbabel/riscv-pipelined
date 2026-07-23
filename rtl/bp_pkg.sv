package bp_pkg;

  // History length
  parameter int GhistLen = 10;
  parameter int PhtDepth = 1 << GhistLen;

  // Direct mapped BTB
  parameter int BtbIdxLen = 6;
  parameter int BtbDepth = 1 << BtbIdxLen;

endpackage
