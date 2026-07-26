module dcache
  import cache_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // Core
    input  logic            cpu_valid,
    input  logic            cpu_rw,
    input  logic [XLEN-1:0] cpu_addr,
    input  logic [XLEN-1:0] cpu_wdata,
    input  logic [     3:0] cpu_wstrb,
    output logic [XLEN-1:0] cpu_rdata,
    output logic            cpu_ready,

    // Memory
    output logic                mem_valid,
    output logic                mem_rw,
    output logic [    XLEN-1:0] mem_addr,
    output logic [LineBits-1:0] mem_wdata,
    input  logic [LineBits-1:0] mem_rdata,
    input  logic                mem_ready,

    // Counters
    output logic [31:0] hit_count,
    output logic [31:0] miss_count
);

  typedef enum logic [2:0] {
    INIT,
    IDLE,
    COMPARE,
    WRITE_BACK,
    ALLOCATE
  } state_t;

  state_t state, next_state;

  // Tag carries flags
  localparam int TagWordW = DcTagLen + 2;
  localparam int ValidBit = DcTagLen + 1;
  localparam int DirtyBit = DcTagLen;

  // Tree in flops
  logic [DcSets-1:0][DcWays-2:0] plru_mem;

  logic [ DcTagLen-1:0] addr_tag;
  logic [ DcIdxLen-1:0] addr_idx;
  logic [BlkOffLen-1:0] addr_word;
  logic [ DcIdxLen-1:0] rd_idx;
  logic [ DcIdxLen-1:0] wr_idx;
  logic [ DcIdxLen-1:0] init_ctr;

  logic [     XLEN-1:0] req_addr;
  logic [     XLEN-1:0] req_wdata;
  logic [          3:0] req_wstrb;
  logic                 req_rw;
  logic                 refill;

  logic [ TagWordW-1:0] tag_rd    [DcWays];
  logic [ LineBits-1:0] line_rd   [DcWays];
  logic [ TagWordW-1:0] tag_q     [DcWays];
  logic [ LineBits-1:0] line_q    [DcWays];

  logic [ TagWordW-1:0] tag_wdata [DcWays];
  logic                 tag_we    [DcWays];
  logic                 data_we   [DcWays];
  logic [ LineBits-1:0] data_wdata;

  logic                 fill_q;
  logic [ DcWaySel-1:0] victim_way_q;
  logic [ TagWordW-1:0] fill_tag_q;
  logic [ LineBits-1:0] fill_line_q;

  logic [   DcWays-1:0] way_hit;
  logic [   DcWays-1:0] way_valid;
  logic                 hit;
  logic [ DcWaySel-1:0] hit_way;
  logic [ DcWays-2:0] plru_tree;
  logic [ DcWays-2:0] plru_next;
  logic [ DcWaySel-1:0] plru_way;
  logic [ DcWaySel-1:0] victim_way;
  logic                 victim_dirty;
  logic [ DcTagLen-1:0] victim_tag;
  logic [ LineBits-1:0] victim_line;
  logic [ LineBits-1:0] line_read;
  logic [ LineBits-1:0] line_write;
  logic                 fill;
  logic                 write_hit;
  logic                 init_done;

  assign addr_tag = req_addr[XLEN-1 : XLEN-DcTagLen];
  assign addr_idx = req_addr[XLEN-DcTagLen-1 : XLEN-DcTagLen-DcIdxLen];
  assign addr_word = req_addr[XLEN-DcTagLen-DcIdxLen-1 : 2];

  assign rd_idx = (state == IDLE) ? cpu_addr[IdxLsb+:DcIdxLen] : addr_idx;
  assign fill = (state == ALLOCATE) && mem_ready;
  assign init_done = (init_ctr == DcIdxLen'(DcSets - 1));

  // Fill bypasses read
  always_comb begin
    for (int w = 0; w < DcWays; w++) begin
      if (fill_q && (victim_way_q == DcWaySel'(w))) begin
        tag_q[w]  = fill_tag_q;
        line_q[w] = fill_line_q;
      end else begin
        tag_q[w]  = tag_rd[w];
        line_q[w] = line_rd[w];
      end
    end
  end

  always_comb begin
    for (int w = 0; w < DcWays; w++) begin
      way_valid[w] = tag_q[w][ValidBit];
      way_hit[w]   = way_valid[w] && (tag_q[w][DcTagLen-1:0] == addr_tag);
    end
  end
  assign hit = |way_hit;
  always_comb begin
    hit_way = '0;
    for (int w = 0; w < DcWays; w++) if (way_hit[w]) hit_way = DcWaySel'(w);
  end
  assign write_hit = (state == COMPARE) && hit && req_rw;

  // Bit 0 old half, 1 old of 01, 2 old of 23
  assign plru_tree = plru_mem[addr_idx];
  assign plru_way[1] = plru_tree[0];
  assign plru_way[0] = plru_tree[0] ? plru_tree[2] : plru_tree[1];

  // Invalid way first
  always_comb begin
    victim_way = plru_way;
    for (int w = DcWays - 1; w >= 0; w--) begin
      if (!way_valid[w]) victim_way = DcWaySel'(w);
    end
  end
  assign victim_dirty = tag_q[victim_way][ValidBit] && tag_q[victim_way][DirtyBit];
  assign victim_tag = tag_q[victim_way][DcTagLen-1:0];
  assign victim_line = line_q[victim_way];

  assign line_read = line_q[hit_way];
  assign cpu_rdata = line_read[addr_word*32+:32];

  // Merge store bytes
  always_comb begin
    line_write = line_read;
    for (int i = 0; i < 4; i++) begin
      if (req_wstrb[i]) begin
        line_write[addr_word*32+i*8+:8] = req_wdata[i*8+:8];
      end
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      INIT: if (init_done) next_state = IDLE;
      IDLE: if (cpu_valid) next_state = COMPARE;
      COMPARE: begin
        if (hit) next_state = IDLE;
        else if (victim_dirty) next_state = WRITE_BACK;
        else next_state = ALLOCATE;
      end
      WRITE_BACK: if (mem_ready) next_state = ALLOCATE;
      ALLOCATE: if (mem_ready) next_state = COMPARE;
      default: ;
    endcase
  end

  assign cpu_ready = (state == COMPARE) && hit;

  assign mem_valid = (state == WRITE_BACK) || (state == ALLOCATE);
  assign mem_rw = (state == WRITE_BACK);
  assign mem_wdata = victim_line;
  assign mem_addr = (state == WRITE_BACK) ? {victim_tag, addr_idx, {IdxLsb{1'b0}}} :
                                            {addr_tag, addr_idx, {IdxLsb{1'b0}}};

  always_ff @(posedge clk) begin
    if (!rst_n) state <= INIT;
    else if (core_en) state <= next_state;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) init_ctr <= '0;
    else if (core_en && (state == INIT)) init_ctr <= init_ctr + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      req_addr  <= '0;
      req_wdata <= '0;
      req_wstrb <= '0;
      req_rw    <= 1'b0;
    end else if (core_en && cpu_valid && (state == IDLE)) begin
      req_addr  <= cpu_addr;
      req_wdata <= cpu_wdata;
      req_wstrb <= cpu_wstrb;
      req_rw    <= cpu_rw;
    end
  end

  // Way write ports
  assign wr_idx = (state == INIT) ? init_ctr : addr_idx;
  assign data_wdata = fill ? mem_rdata : line_write;

  always_comb begin
    for (int w = 0; w < DcWays; w++) begin
      if (state == INIT) begin
        tag_we[w]    = 1'b1;
        data_we[w]   = 1'b0;
        tag_wdata[w] = '0;
      end else if (fill && (victim_way == DcWaySel'(w))) begin
        tag_we[w]    = 1'b1;
        data_we[w]   = 1'b1;
        tag_wdata[w] = {1'b1, 1'b0, addr_tag};
      end else if (write_hit && (hit_way == DcWaySel'(w))) begin
        tag_we[w]    = 1'b1;
        data_we[w]   = 1'b1;
        tag_wdata[w] = {1'b1, 1'b1, addr_tag};
      end else begin
        tag_we[w]    = 1'b0;
        data_we[w]   = 1'b0;
        tag_wdata[w] = '0;
      end
    end
  end

  for (genvar w = 0; w < DcWays; w++) begin : g_way
    bram_sdp #(
        .Width(TagWordW),
        .Depth(DcSets),
        .Block(1'b0)
    ) u_tag (
        .clk  (clk),
        .we   (core_en && tag_we[w]),
        .wlane('1),
        .widx (wr_idx),
        .wdata(tag_wdata[w]),
        .re   (core_en),
        .ridx (rd_idx),
        .rdata(tag_rd[w])
    );

    bram_sdp #(
        .Width(LineBits),
        .Depth(DcSets),
        .Block(1'b0)
    ) u_data (
        .clk  (clk),
        .we   (core_en && data_we[w]),
        .wlane('1),
        .widx (wr_idx),
        .wdata(data_wdata),
        .re   (core_en),
        .ridx (rd_idx),
        .rdata(line_rd[w])
    );
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      fill_q <= 1'b0;
    end else if (core_en) begin
      fill_q       <= fill;
      victim_way_q <= victim_way;
      fill_tag_q   <= {1'b1, 1'b0, addr_tag};
      fill_line_q  <= mem_rdata;
    end
  end

  // Touch points away
  always_comb begin
    plru_next = plru_tree;
    plru_next[0] = ~hit_way[1];
    if (hit_way[1]) plru_next[2] = ~hit_way[0];
    else plru_next[1] = ~hit_way[0];
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      plru_mem <= '0;
    end else if (core_en && (state == COMPARE) && hit) begin
      plru_mem[addr_idx] <= plru_next;
    end
  end

  // Count miss once
  always_ff @(posedge clk) begin
    if (!rst_n) refill <= 1'b0;
    else if (core_en) begin
      if ((state == COMPARE) && !hit) refill <= 1'b1;
      else if (state == IDLE) refill <= 1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      hit_count  <= '0;
      miss_count <= '0;
    end else if (core_en && (state == COMPARE)) begin
      if (!hit) miss_count <= miss_count + 1;
      else if (!refill) hit_count <= hit_count + 1;
    end
  end

endmodule
