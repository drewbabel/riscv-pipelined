module gate_check_tb ();
  import cache_pkg::*;
  localparam int DEPTH = 16384, ClkDiv = 32, MaxChars = 2;
  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];
  logic [LineBits-1:0] pline;
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
    rst = 1;
    if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "build/jalret.hex";
    for (int k = 0; k < DEPTH; k++) img[k] = 0;
    $readmemh(hexfile, img);
    if (img[0] == 32'h0) $fatal(1, "%s missing or empty", hexfile);
    for (int l = 0; l < DEPTH / LineWords; l++) begin
      for (int w = 0; w < LineWords; w++) pline[32*w+:32] = img[l*LineWords+w];
      @(negedge clk);
      dut.imem_inst.u_line.bd_idx  = l;
      dut.imem_inst.u_line.bd_data = pline;
      dut.imem_inst.u_line.bd_we   = 1'b1;
      dut.dmem_inst.u_line.bd_idx  = l;
      dut.dmem_inst.u_line.bd_data = pline;
      dut.dmem_inst.u_line.bd_we   = 1'b1;
    end
    @(negedge clk);
    dut.imem_inst.u_line.bd_we = 1'b0;
    dut.dmem_inst.u_line.bd_we = 1'b0;
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
