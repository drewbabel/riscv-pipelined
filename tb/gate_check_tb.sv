// pc_plus4 keep smoke check
module gate_check_tb ();
  localparam int DEPTH = 16384, ClkDiv = 32, MaxChars = 2;
  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];
  string hexfile;
  int nchars = 0;
  always #5 clk = ~clk;
  board_top #(
      .DEPTH (DEPTH),
      .ClkDiv(ClkDiv)
  ) dut (
      .clk,
      .rst,
      .sw,
      .led,
      .uart_rx,
      .uart_tx
  );

  task automatic monitor();
    forever begin
      @(posedge clk);
      if (dut.tx_valid) begin
        $write("%c", dut.store_data[7:0]);
        $fflush();
        nchars++;
        if (nchars >= MaxChars) $finish;
      end
    end
  endtask

  initial begin
    if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "build/jalret.hex";
    for (int k = 0; k < DEPTH; k++) img[k] = 0;
    $readmemh(hexfile, img);
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
    force dut.loading = 1'b0;
    repeat (400) @(posedge clk);
    fork
      monitor();
    join_none
    repeat (200_000) @(posedge clk);
    $finish;
  end
endmodule
