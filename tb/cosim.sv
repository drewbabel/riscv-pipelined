module cosim ();

  int checks = 0;

  localparam int Xlen = 32;
  localparam int Depth = 64;

  logic             clk = 1'b0;
  logic             rst_n;
  logic  [Xlen-1:0] pc;
  logic  [Xlen-1:0] alu_result;
  logic  [Xlen-1:0] write_data;
  logic             mem_write;

  string            hexfile;
  int               max_commits;

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

  // RVFI retirement taps
  logic            r_valid;
  logic            r_hold;
  logic [Xlen-1:0] r_pc;
  logic [Xlen-1:0] r_insn;
  logic [Xlen-1:0] r_wdata;
  logic            r_rw;
  logic [Xlen-1:0] r_maddr;
  logic [     3:0] r_wmask;
  logic [Xlen-1:0] r_sdata;
  assign r_valid = dut.riscv_pipelined_inst.dbg_valid;
  assign r_hold  = dut.riscv_pipelined_inst.datapath_inst.muldiv_hold;
  assign r_pc    = dut.riscv_pipelined_inst.dbg_pc_rdata;
  assign r_insn  = dut.riscv_pipelined_inst.dbg_insn;
  assign r_wdata = dut.riscv_pipelined_inst.dbg_rd_wdata;
  assign r_rw    = dut.riscv_pipelined_inst.dbg_reg_write;
  assign r_maddr = dut.riscv_pipelined_inst.dbg_mem_addr;
  assign r_wmask = dut.riscv_pipelined_inst.dbg_mem_wmask;
  assign r_sdata = dut.riscv_pipelined_inst.dbg_mem_wdata;

  task automatic do_reset();
    rst_n = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
  endtask  // Automatic

  // One line per retired instruction
  task automatic emit_commit();
    logic [4:0] rd;
    rd = r_insn[11:7];
    // pc rd rd_val mem_write mem_addr wstrb store_data
    $display("COMMIT %08x %0d %08x %0d %08x %1x %08x", r_pc, (r_rw && rd != 0) ? rd : 0, r_wdata,
             |r_wmask, r_maddr, r_wmask, r_sdata);
    checks++;
  endtask  // Automatic

  initial begin
    logic [Xlen-1:0] last_pc;
    logic            have_last;
    logic            stop;

    if (!$value$plusargs("hex=%s", hexfile)) $fatal(1, "cosim needs +hex");
    if (!$value$plusargs("n=%d", max_commits)) max_commits = 4000;

    $readmemh(hexfile, dut.imem_inst.mem);
    do_reset();

    // Stop when park sentinel repeats
    have_last = 0;
    stop      = 0;
    for (int i = 0; i < max_commits && !stop; i++) begin
      @(posedge clk);
      #1;
      if (r_valid && !r_hold) begin
        if (have_last && r_pc === last_pc) stop = 1;
        else begin
          emit_commit();
          last_pc   = r_pc;
          have_last = 1;
        end
      end
    end

    $display("MONITOR: %0d commits", checks);
    $finish;
  end

endmodule
