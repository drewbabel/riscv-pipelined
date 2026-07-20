module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);

  // Free solver inputs
  (* keep *)`rvformal_rand_reg [31:0] instr;
  (* keep *)`rvformal_rand_reg [31:0] read_data;

  (* keep *)logic              [31:0] pc;
  (* keep *)logic              [31:0] alu_result;
  (* keep *)logic              [31:0] write_data;
  (* keep *)logic              [ 3:0] store_wstrb;
  (* keep *)logic              [31:0] store_data;
  (* keep *)logic              [31:0] mem_addr;
  (* keep *)logic                     mem_write;

  // Retirement taps
  (* keep *)logic                     dbg_valid;
  (* keep *)logic              [31:0] dbg_insn;
  (* keep *)logic              [31:0] dbg_pc_rdata;
  (* keep *)logic              [31:0] dbg_pc_wdata;
  (* keep *)logic              [31:0] dbg_rs1_rdata;
  (* keep *)logic              [31:0] dbg_rs2_rdata;
  (* keep *)logic              [31:0] dbg_rd_wdata;
  (* keep *)logic                     dbg_reg_write;
  (* keep *)logic              [31:0] dbg_mem_addr;
  (* keep *)logic              [ 3:0] dbg_mem_wmask;
  (* keep *)logic              [31:0] dbg_mem_wdata;
  (* keep *)logic              [31:0] dbg_mem_rdata;
  (* keep *)logic                     dbg_trap;

  riscv_pipelined uut (
      .clk          (clock),
      .core_en      (1'b1),
      .rst_n        (!reset),
      .instr        (instr),
      .read_data    (read_data),
      .pc           (pc),
      .mem_write    (mem_write),
      .alu_result   (alu_result),
      .write_data   (write_data),
      .store_wstrb  (store_wstrb),
      .store_data   (store_data),
      .mem_addr     (mem_addr),
      .dbg_valid    (dbg_valid),
      .dbg_insn     (dbg_insn),
      .dbg_pc_rdata (dbg_pc_rdata),
      .dbg_pc_wdata (dbg_pc_wdata),
      .dbg_rs1_rdata(dbg_rs1_rdata),
      .dbg_rs2_rdata(dbg_rs2_rdata),
      .dbg_rd_wdata (dbg_rd_wdata),
      .dbg_reg_write(dbg_reg_write),
      .dbg_mem_addr (dbg_mem_addr),
      .dbg_mem_wmask(dbg_mem_wmask),
      .dbg_mem_wdata(dbg_mem_wdata),
      .dbg_mem_rdata(dbg_mem_rdata),
      .dbg_trap     (dbg_trap)
  );

  logic [63:0] order_q;
  logic        rd_nonzero;
  logic [ 3:0] rmask_c;

  always_ff @(posedge clock) begin
    if (reset) order_q <= 64'd0;
    else if (dbg_valid) order_q <= order_q + 64'd1;
  end

  assign rvfi_valid     = dbg_valid && !reset;
  assign rvfi_order     = order_q;
  assign rvfi_insn      = dbg_insn;
  assign rvfi_trap      = dbg_trap;
  assign rvfi_halt      = 1'b0;
  assign rvfi_intr      = 1'b0;
  assign rvfi_mode      = 2'd3;
  assign rvfi_ixl       = 2'd1;

  assign rd_nonzero     = dbg_reg_write && (dbg_insn[11:7] != 5'd0);
  assign rvfi_rs1_addr  = dbg_insn[19:15];
  assign rvfi_rs2_addr  = dbg_insn[24:20];
  assign rvfi_rs1_rdata = dbg_rs1_rdata;
  assign rvfi_rs2_rdata = dbg_rs2_rdata;
  assign rvfi_rd_addr   = rd_nonzero ? dbg_insn[11:7] : 5'd0;
  assign rvfi_rd_wdata  = rd_nonzero ? dbg_rd_wdata : 32'd0;

  assign rvfi_pc_rdata  = dbg_pc_rdata;
  assign rvfi_pc_wdata  = dbg_pc_wdata;

  assign rvfi_mem_addr  = {dbg_mem_addr[31:2], 2'b00};
  assign rvfi_mem_wmask = dbg_mem_wmask;
  assign rvfi_mem_rmask = rmask_c;
  assign rvfi_mem_rdata = dbg_mem_rdata;
  assign rvfi_mem_wdata = dbg_mem_wdata;

  always_comb begin
    rmask_c = 4'b0000;
    if (dbg_insn[6:0] == 7'b0000011) begin
      case (dbg_insn[14:12])
        3'b000, 3'b100: rmask_c = 4'b0001 << dbg_mem_addr[1:0];
        3'b001, 3'b101: rmask_c = 4'b0011 << dbg_mem_addr[1:0];
        3'b010:         rmask_c = 4'b1111;
        default:        rmask_c = 4'b0000;
      endcase
    end
  end

endmodule
