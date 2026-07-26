package cache_pkg;

  // Line geometry
  parameter int LineWords = 4;
  parameter int LineBits = 32 * LineWords;
  parameter int BlkOffLen = $clog2(LineWords);
  parameter int IdxLsb = 2 + BlkOffLen;

  // Instruction cache
  parameter int IcIdxLen = 9;
  parameter int IcSets = 1 << IcIdxLen;
  parameter int IcTagLen = 32 - IdxLsb - IcIdxLen;

  // Data cache
  parameter int DcIdxLen = 7;
  parameter int DcSets = 1 << DcIdxLen;
  parameter int DcWays = 4;
  parameter int DcWaySel = $clog2(DcWays);
  parameter int DcTagLen = 32 - IdxLsb - DcIdxLen;

endpackage
