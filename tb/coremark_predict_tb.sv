module coremark_predict_tb ();
  localparam int DEPTH = 16384;
  localparam int ClkDiv = 2;
  localparam int FastClkHz = 100_000_000;
  localparam int BaudRate = 28_800;
  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;

  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];

  int branches = 0;
  int mispredicts = 0;

  always #5 clk = ~clk;

  board_top #(
      .DEPTH (DEPTH),
      .ClkDiv(ClkDiv)
  ) dut (
      .clk    (clk),
      .rst    (rst),
      .sw     (sw),
      .led    (led),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx)
  );

  task automatic send_byte(input logic [7:0] b);
    uart_rx = 0;
    repeat (ClksPerBit) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      uart_rx = b[i];
      repeat (ClksPerBit) @(posedge clk);
    end
    uart_rx = 1;
    repeat (ClksPerBit) @(posedge clk);
  endtask  // Automatic

  wire v_ex = dut.riscv_pipelined_inst.datapath_inst.valid_ex;
  wire b_ex = dut.riscv_pipelined_inst.datapath_inst.branch_ex;
  wire mis = dut.riscv_pipelined_inst.datapath_inst.mispredict;
  wire c_en = dut.core_en;

  always @(posedge clk) begin
    if (!rst && c_en && v_ex && b_ex) begin
      branches++;
      if (mis) mispredicts++;
    end
  end

  initial begin
    for (int k = 0; k < DEPTH; k++) img[k] = 32'h0;
    $readmemh("sw/coremark/coremark_sim.hex", img);
    #1;  // after mem init
    for (int k = 0; k < DEPTH; k++) begin
      dut.imem_inst.g_lane[0].bmem[k] = img[k][7:0];
      dut.imem_inst.g_lane[1].bmem[k] = img[k][15:8];
      dut.imem_inst.g_lane[2].bmem[k] = img[k][23:16];
      dut.imem_inst.g_lane[3].bmem[k] = img[k][31:24];
      dut.dmem_inst.g_lane[0].bmem[k] = img[k][7:0];
      dut.dmem_inst.g_lane[1].bmem[k] = img[k][15:8];
      dut.dmem_inst.g_lane[2].bmem[k] = img[k][23:16];
      dut.dmem_inst.g_lane[3].bmem[k] = img[k][31:24];
    end
    rst = 1;
    sw  = 0;
    repeat (2) @(posedge clk);
    rst = 0;
    repeat (2000) @(posedge clk);
    repeat (4) send_byte(8'd0);

    wait (branches >= 30_000);
    $display("PROBE branches=%0d mispredicts=%0d rate=%0d.%02d%% pc=%08x", branches, mispredicts,
             (100 * mispredicts) / branches, ((10000 * mispredicts) / branches) % 100,
             dut.riscv_pipelined_inst.pc);
    $finish;
  end

  initial begin
    repeat (60_000_000) @(posedge clk);
    $fatal(1, "TIMEOUT");
  end
endmodule
