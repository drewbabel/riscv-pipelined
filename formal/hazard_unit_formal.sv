module hazard_unit_formal ();

  localparam int XLEN = 32;

  localparam logic [1:0] FwdNone = 2'b00;
  localparam logic [1:0] FwdMem = 2'b01;
  localparam logic [1:0] FwdWb = 2'b10;
  localparam logic [1:0] ResMem = 2'd1;

  logic       clk;
  logic       core_en;
  logic       rst_n;
  logic [4:0] rs1_id;
  logic [4:0] rs2_id;
  logic [4:0] rs1_ex;
  logic [4:0] rs2_ex;
  logic [4:0] rd_id;
  logic [4:0] rd_ex;
  logic [4:0] rd_mem;
  logic [4:0] rd_wb;
  logic       reg_write_mem;
  logic       reg_write_wb;
  logic       mem_write_ex;
  logic [1:0] result_src_ex;
  logic [1:0] result_src_mem;
  logic [1:0] result_src_wb;
  logic       stall;
  logic [1:0] forward_a;
  logic [1:0] forward_b;

  hazard_unit #(
      .XLEN(XLEN)
  ) dut (
      .clk           (clk),
      .core_en       (core_en),
      .rst_n         (rst_n),
      .rs1_id        (rs1_id),
      .rs2_id        (rs2_id),
      .rs1_ex        (rs1_ex),
      .rs2_ex        (rs2_ex),
      .rd_id         (rd_id),
      .rd_ex         (rd_ex),
      .rd_mem        (rd_mem),
      .rd_wb         (rd_wb),
      .reg_write_mem (reg_write_mem),
      .reg_write_wb  (reg_write_wb),
      .mem_write_ex  (mem_write_ex),
      .result_src_ex (result_src_ex),
      .result_src_mem(result_src_mem),
      .result_src_wb (result_src_wb),
      .stall         (stall),
      .forward_a     (forward_a),
      .forward_b     (forward_b)
  );

  always @(posedge clk) begin
    assert (forward_a !== 2'b11);
    assert (forward_b !== 2'b11);

    // MEM firing and priority
    if (reg_write_mem && (rd_mem != 0) && (rd_mem == rs1_ex)) begin
      assert (forward_a == FwdMem);
    end else if (reg_write_wb && (rd_wb != 0) && (rd_wb == rs1_ex)) begin
      assert (forward_a == FwdWb);
    end else begin
      assert (forward_a == FwdNone);
    end

    // x0 never forwarded
    if (rd_mem == 0) assert ((forward_a !== FwdMem) && (forward_b !== FwdMem));

    // Stall-only for load-use hazard
    if (stall) assert (result_src_ex == ResMem);

    // Correct stall firing
    if (result_src_ex == ResMem && rd_ex != 0 && (rd_ex == rs1_id || rd_ex == rs2_id)) begin
      assert (stall);
    end else begin
      assert (!stall);
    end
  end

endmodule
