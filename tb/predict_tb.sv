module predict_tb ();

  localparam int Xlen = 32;
  localparam int Depth = 64;
  localparam int MaxCycles = 400;

  logic            clk = 1'b0;
  logic            rst_n;
  logic [Xlen-1:0] pc;
  logic [Xlen-1:0] alu_result;
  logic [Xlen-1:0] write_data;
  logic            mem_write;

  int              branches = 0;
  int              mispredicts = 0;

  always #5 clk = ~clk;

  top #(
      .XLEN (Xlen),
      .DEPTH(Depth)
  ) dut (
      .clk       (clk),
      .rst_n     (rst_n),
      .pc        (pc),
      .alu_result(alu_result),
      .write_data(write_data),
      .mem_write (mem_write)
  );

  // Resolve taps
  logic core_valid_ex, core_branch_ex, core_mispred;
  assign core_valid_ex  = dut.riscv_pipelined_inst.datapath_inst.valid_ex;
  assign core_branch_ex = dut.riscv_pipelined_inst.datapath_inst.branch_ex;
  assign core_mispred   = dut.riscv_pipelined_inst.datapath_inst.mispredict;

  task automatic do_reset();
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask  // Automatic

  always @(posedge clk) begin
    if (rst_n && core_valid_ex && core_branch_ex) begin
      branches++;
      if (core_mispred) mispredicts++;
    end
  end

  initial begin
    for (int i = 0; i < Depth; i++) dut.imem_inst.mem[i] = 32'h00000013;  // NOP fill
    $readmemh("tests/pl_predict.hex", dut.imem_inst.mem);
    do_reset();
    repeat (MaxCycles) @(posedge clk);

    $display("branches=%0d mispredicts=%0d rate=%0d%%", branches, mispredicts,
             (branches == 0) ? 0 : (100 * mispredicts) / branches);
    $finish;
  end

endmodule
