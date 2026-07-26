module coremark_boot_tb ();

  import cache_pkg::*;
  localparam int DEPTH = 16384;
  localparam int FastClkHz = 100_000_000;
  localparam int ClkDiv = 32;
  localparam int MemLat = 20;
  localparam int CoreClkHz = FastClkHz / ClkDiv;
  localparam int BaudRate = 28_800;
  localparam int ClksPerBit = (FastClkHz + BaudRate / 2) / BaudRate;
  localparam int RxBitFast = ((CoreClkHz + BaudRate / 2) / BaudRate) * ClkDiv;

  logic clk = 0, rst;
  logic [15:0] sw, led;
  logic uart_rx = 1, uart_tx;
  logic [31:0] img[DEPTH];
  logic [LineBits-1:0] pline;

  always #5 clk = ~clk;

  board_top #(
      .DEPTH(DEPTH),
      .ClkDiv(ClkDiv),
      .MemLatency(MemLat)
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

  // Serial monitor
  task automatic monitor();
    logic [7:0] c;
    forever begin
      @(negedge uart_tx);
      repeat (RxBitFast / 2) @(posedge clk);
      for (int i = 0; i < 8; i++) begin
        repeat (RxBitFast) @(posedge clk);
        c[i] = uart_tx;
      end
      repeat (RxBitFast) @(posedge clk);
      $write("%c", c);
      $fflush();
    end
  endtask  // Automatic

  initial begin
    rst = 1;
    for (int k = 0; k < DEPTH; k++) img[k] = 32'h0;
    $readmemh("sw/coremark/coremark_sim.hex", img);
    if (img[0] == 32'h0)
      $fatal(1, "coremark_sim.hex missing or empty, run make -C sw/coremark all");
    #1;  // After mem init
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
    repeat (2000) @(posedge clk);
    repeat (4) send_byte(8'd0);

    fork
      monitor();
    join_none

    wait (led == 16'hC0DE);
    repeat (5000) @(posedge clk);
    $display("\n[coremark_boot_tb] CoreMark finished (LED sentinel 0xC0DE)");
    $finish;
  end

  // Watchdog
  initial begin
    repeat (2_000_000_000) @(posedge clk);
    $fatal(1, "TIMEOUT before CoreMark completion");
  end
endmodule
