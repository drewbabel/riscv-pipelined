`default_nettype none

module mem_arb_formal
  import cache_pkg::*;
();

  localparam int Xlen = 32;
  localparam int AppAddrW = 29;
  localparam int MaskW = LineBits / 8;
  localparam logic [2:0] AppRead = 3'b001;

  localparam int InflightW = 4;

  logic                clk;

  // Free requester stimulus
  (* anyseq *)logic                core_en;
  (* anyseq *)logic                ic_req_valid;
  (* anyseq *)logic [    Xlen-1:0] ic_req_addr;
  (* anyseq *)logic                dc_req_valid;
  (* anyseq *)logic                dc_req_rw;
  (* anyseq *)logic [    Xlen-1:0] dc_req_addr;
  (* anyseq *)logic [LineBits-1:0] dc_req_wdata;
  (* anyseq *)logic                boot_we;
  (* anyseq *)logic [    Xlen-1:0] boot_addr;
  (* anyseq *)logic [    Xlen-1:0] boot_wdata;

  // Free controller stimulus
  (* anyseq *)logic                app_rdy;
  (* anyseq *)logic                app_wdf_rdy;
  (* anyseq *)logic                rd_deliver;
  (* anyseq *)logic                calib_pulse;
  (* anyseq *)logic [LineBits-1:0] rd_payload;

  logic                calib_done;

  logic [LineBits-1:0] ic_resp_rdata;
  logic                ic_resp_ready;
  logic [LineBits-1:0] dc_resp_rdata;
  logic                dc_resp_ready;

  logic [AppAddrW-1:0] app_addr;
  logic [         2:0] app_cmd;
  logic                app_en;

  logic [LineBits-1:0] app_wdf_data;
  logic [   MaskW-1:0] app_wdf_mask;
  logic                app_wdf_wren;
  logic                app_wdf_end;

  logic [LineBits-1:0] app_rd_data;
  logic                app_rd_data_valid;

  logic [         1:0] dbg_state;
  logic [         1:0] dbg_src;
  logic                dbg_cmd_done;
  logic                dbg_wdf_done;
  logic                dbg_resp_pending;
  logic                dbg_req_rw;

  logic                rst_n;
  logic [         7:0] t = 8'd0;
  logic                f_past_valid = 1'b0;

  initial assume (t == 8'd0);
  always @(posedge clk) begin
    t <= (t == 8'hFF) ? 8'hFF : t + 8'd1;
    f_past_valid <= 1'b1;
  end
  assign rst_n = (t != 8'd0);

  // calib_done rises once
  always @(posedge clk) begin
    if (!rst_n) calib_done <= 1'b0;
    else if (calib_pulse) calib_done <= 1'b1;
  end

  mem_arb #(
      .XLEN(Xlen),
      .APP_ADDR_WIDTH(AppAddrW)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .core_en(core_en),
      .calib_done(calib_done),
      .ic_req_valid(ic_req_valid),
      .ic_req_addr(ic_req_addr),
      .ic_resp_rdata(ic_resp_rdata),
      .ic_resp_ready(ic_resp_ready),
      .dc_req_valid(dc_req_valid),
      .dc_req_rw(dc_req_rw),
      .dc_req_addr(dc_req_addr),
      .dc_req_wdata(dc_req_wdata),
      .dc_resp_rdata(dc_resp_rdata),
      .dc_resp_ready(dc_resp_ready),
      .boot_we(boot_we),
      .boot_addr(boot_addr),
      .boot_wdata(boot_wdata),
      .app_addr(app_addr),
      .app_cmd(app_cmd),
      .app_en(app_en),
      .app_rdy(app_rdy),
      .app_wdf_data(app_wdf_data),
      .app_wdf_mask(app_wdf_mask),
      .app_wdf_wren(app_wdf_wren),
      .app_wdf_end(app_wdf_end),
      .app_wdf_rdy(app_wdf_rdy),
      .app_rd_data(app_rd_data),
      .app_rd_data_valid(app_rd_data_valid),
      .dbg_state(dbg_state),
      .dbg_src(dbg_src),
      .dbg_cmd_done(dbg_cmd_done),
      .dbg_wdf_done(dbg_wdf_done),
      .dbg_resp_pending(dbg_resp_pending),
      .dbg_req_rw(dbg_req_rw)
  );

  // Handshake fires
  logic cmd_fire;
  logic wdf_fire;
  logic rd_cmd_fire;
  assign cmd_fire    = app_en && app_rdy;
  assign wdf_fire    = app_wdf_wren && app_wdf_rdy;
  assign rd_cmd_fire = cmd_fire && (app_cmd == AppRead);

  // Read return model
  logic [InflightW-1:0] rd_inflight;

  assign app_rd_data_valid = rd_deliver && (rd_inflight != '0);
  assign app_rd_data = rd_payload;

  always @(posedge clk) begin
    if (!rst_n) rd_inflight <= '0;
    else if (rd_cmd_fire && !app_rd_data_valid && !(&rd_inflight))
      rd_inflight <= rd_inflight + 1'b1;
    else if (!rd_cmd_fire && app_rd_data_valid) rd_inflight <= rd_inflight - 1'b1;
  end

  // Environment integrity
  always @(posedge clk) if (rst_n) assert (!(&rd_inflight));

  // Last payload returned
  logic [LineBits-1:0] f_last_rd_data;
  always @(posedge clk) if (app_rd_data_valid) f_last_rd_data <= app_rd_data;

  // Fairness window
  localparam int GapMax = 2;
  localparam int GapW = 4;

  logic [GapW-1:0] gap_rdy;
  logic [GapW-1:0] gap_wdf;
  logic [GapW-1:0] gap_rd;
  logic [GapW-1:0] gap_en;
  logic [GapW-1:0] gap_calib;

  always @(posedge clk) begin
    if (!rst_n) begin
      gap_rdy   <= '0;
      gap_wdf   <= '0;
      gap_rd    <= '0;
      gap_en    <= '0;
      gap_calib <= '0;
    end else begin
      gap_rdy   <= app_rdy ? '0 : gap_rdy + 1'b1;
      gap_wdf   <= app_wdf_rdy ? '0 : gap_wdf + 1'b1;
      gap_rd    <= rd_deliver ? '0 : gap_rd + 1'b1;
      gap_en    <= core_en ? '0 : gap_en + 1'b1;
      gap_calib <= calib_done ? '0 : gap_calib + 1'b1;
    end
  end

  always @(posedge clk)
    if (rst_n) begin
      assume (gap_rdy <= GapW'(GapMax));
      assume (gap_wdf <= GapW'(GapMax));
      assume (gap_rd <= GapW'(GapMax));
      assume (gap_en <= GapW'(GapMax));
      assume (gap_calib <= GapW'(GapMax));
    end

  // Outstanding transactions
  localparam int OutW = 4;

  logic wr_cmd_fire;
  assign wr_cmd_fire = cmd_fire && (app_cmd != AppRead);

  logic [OutW-1:0] out_reads;
  logic [OutW-1:0] out_wr_cmds;
  logic [OutW-1:0] out_wr_beats;
  logic [OutW-1:0] out_total;

  always @(posedge clk) begin
    if (!rst_n) begin
      out_reads    <= '0;
      out_wr_cmds  <= '0;
      out_wr_beats <= '0;
    end else begin
      if (rd_cmd_fire && !app_rd_data_valid) out_reads <= out_reads + 1'b1;
      else if (!rd_cmd_fire && app_rd_data_valid) out_reads <= out_reads - 1'b1;

      if (wr_cmd_fire && !wdf_fire) begin
        if (out_wr_beats != '0) out_wr_beats <= out_wr_beats - 1'b1;
        else out_wr_cmds <= out_wr_cmds + 1'b1;
      end else if (wdf_fire && !wr_cmd_fire) begin
        if (out_wr_cmds != '0) out_wr_cmds <= out_wr_cmds - 1'b1;
        else out_wr_beats <= out_wr_beats + 1'b1;
      end
    end
  end

  assign out_total = out_reads + out_wr_cmds + out_wr_beats;

  always @(posedge clk) if (rst_n) assert (out_total <= OutW'(1));

  // Bounded wait
  localparam int WaitMax = 24;
  localparam int WaitW = 8;
  localparam logic [1:0] StIdle = 2'd0;

  logic [WaitW-1:0] wait_ctr;

  always @(posedge clk) begin
    if (!rst_n || (dbg_state == StIdle)) wait_ctr <= '0;
    else wait_ctr <= wait_ctr + 1'b1;
  end

  always @(posedge clk) if (rst_n) assert (wait_ctr < WaitW'(WaitMax));

  // Covers

  localparam logic [1:0] StIssue = 2'd1;
  localparam logic [1:0] StWait = 2'd2;
  localparam logic [1:0] SrcIc = 2'd0;
  localparam logic [1:0] SrcDc = 2'd1;
  localparam logic [1:0] SrcBoot = 2'd2;

  logic [1:0] prev_state;
  logic       retire;
  logic       en_low_seen;
  logic [2:0] rd_age;

  always @(posedge clk) begin
    if (!rst_n) begin
      prev_state  <= StIdle;
      en_low_seen <= 1'b0;
      rd_age      <= '0;
    end else begin
      prev_state <= dbg_state;
      if (dbg_state == StIdle) en_low_seen <= 1'b0;
      else if (!core_en) en_low_seen <= 1'b1;
      if (rd_cmd_fire) rd_age <= '0;
      else if (rd_age != 3'd7) rd_age <= rd_age + 1'b1;
    end
  end

  assign retire = (prev_state == StWait) && (dbg_state == StIdle);

  always @(posedge clk)
    if (rst_n) begin
      cover (retire && (dbg_src == SrcBoot));
      cover (retire && (dbg_src == SrcDc) && dbg_req_rw);
      cover (retire && (dbg_src == SrcDc) && !dbg_req_rw);
      cover (retire && (dbg_src == SrcIc));
      cover (retire && en_low_seen);
      cover ((dbg_state == StIssue) && dbg_wdf_done && !dbg_cmd_done);
      cover ((dbg_state == StIssue) && dbg_cmd_done && !dbg_wdf_done && dbg_req_rw);
      cover (wdf_fire && cmd_fire);
      cover (app_rd_data_valid && (rd_age == 3'd1));
      cover (app_rd_data_valid && (rd_age == 3'd2));
    end

endmodule

`default_nettype wire
