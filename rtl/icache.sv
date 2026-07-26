module icache
  import cache_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // Core
    input  logic            cpu_valid,
    input  logic [XLEN-1:0] cpu_addr,
    output logic [XLEN-1:0] cpu_rdata,
    output logic            cpu_ready,

    // Memory
    output logic                mem_valid,
    output logic [    XLEN-1:0] mem_addr,
    input  logic [LineBits-1:0] mem_rdata,
    input  logic                mem_ready,

    // Counters
    output logic [31:0] hit_count,
    output logic [31:0] miss_count
);

  typedef enum logic [1:0] {
    INIT,
    IDLE,
    COMPARE,
    ALLOCATE
  } state_t;

  state_t state, next_state;

  logic [ IcTagLen-1:0] addr_tag;
  logic [ IcIdxLen-1:0] addr_idx;
  logic [BlkOffLen-1:0] addr_word;
  logic [ IcIdxLen-1:0] rd_idx;
  logic [ IcIdxLen-1:0] init_ctr;
  logic [     XLEN-1:0] req_addr;

  logic [   IcTagLen:0] tag_rd;
  logic [ LineBits-1:0] line_rd;
  logic [   IcTagLen:0] tag_q;
  logic [ LineBits-1:0] line_q;
  logic                 fill_q;
  logic [   IcTagLen:0] fill_tag_q;
  logic [ LineBits-1:0] fill_line_q;

  logic [   IcTagLen:0] tag_wdata;
  logic [ IcIdxLen-1:0] tag_widx;
  logic                 tag_we;

  logic                 hit;
  logic                 refill;
  logic                 fill;
  logic                 init_done;

  assign addr_tag   = req_addr[XLEN-1 : XLEN-IcTagLen];
  assign addr_idx   = req_addr[XLEN-IcTagLen-1 : XLEN-IcTagLen-IcIdxLen];
  assign addr_word  = req_addr[XLEN-IcTagLen-IcIdxLen-1 : 2];

  assign rd_idx     = (state == IDLE) ? cpu_addr[IdxLsb+:IcIdxLen] : addr_idx;
  assign fill       = (state == ALLOCATE) && mem_ready;
  assign init_done  = (init_ctr == IcIdxLen'(IcSets - 1));

  // Fill bypasses read
  assign tag_q      = fill_q ? fill_tag_q : tag_rd;
  assign line_q     = fill_q ? fill_line_q : line_rd;

  assign hit        = tag_q[IcTagLen] && (tag_q[IcTagLen-1:0] == addr_tag);
  assign cpu_rdata  = line_q[addr_word*32+:32];

  // Walk clears valid
  assign tag_we     = (state == INIT) || fill;
  assign tag_widx   = (state == INIT) ? init_ctr : addr_idx;
  assign tag_wdata  = (state == INIT) ? '0 : {1'b1, addr_tag};

  assign cpu_ready  = (state == COMPARE) && hit;
  assign mem_valid  = (state == ALLOCATE);
  assign mem_addr   = {addr_tag, addr_idx, {IdxLsb{1'b0}}};

  always_ff @(posedge clk) begin
    if (!rst_n) state <= INIT;
    else if (core_en) state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      INIT: if (init_done) next_state = IDLE;
      IDLE: if (cpu_valid) next_state = COMPARE;
      COMPARE: begin
        if (hit) next_state = IDLE;
        else next_state = ALLOCATE;
      end
      ALLOCATE: if (mem_ready) next_state = COMPARE;
      default: ;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) init_ctr <= '0;
    else if (core_en && (state == INIT)) init_ctr <= init_ctr + 1'b1;
  end

  always_ff @(posedge clk) begin
    if (!rst_n) req_addr <= '0;
    else if (core_en && cpu_valid && (state == IDLE)) req_addr <= cpu_addr;
  end

  // Tag carries valid
  bram_sdp #(
      .Width(IcTagLen + 1),
      .Depth(IcSets)
  ) u_tag (
      .clk  (clk),
      .we   (core_en && tag_we),
      .wlane('1),
      .widx (tag_widx),
      .wdata(tag_wdata),
      .re   (core_en),
      .ridx (rd_idx),
      .rdata(tag_rd)
  );

  bram_sdp #(
      .Width(LineBits),
      .Depth(IcSets)
  ) u_data (
      .clk  (clk),
      .we   (core_en && fill),
      .wlane('1),
      .widx (addr_idx),
      .wdata(mem_rdata),
      .re   (core_en),
      .ridx (rd_idx),
      .rdata(line_rd)
  );

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      fill_q <= 1'b0;
    end else if (core_en) begin
      fill_q      <= fill;
      fill_tag_q  <= {1'b1, addr_tag};
      fill_line_q <= mem_rdata;
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
    end else if (core_en) begin
      if (state == COMPARE) begin
        if (!hit) miss_count <= miss_count + 1;
        else if (!refill) hit_count <= hit_count + 1;
      end
    end
  end

endmodule
