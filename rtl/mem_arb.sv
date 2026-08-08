module mem_arb
  import cache_pkg::*;
#(
    parameter int XLEN = 32,
    parameter int APP_ADDR_WIDTH = 29,
    localparam int MaskBits = LineBits / 8
) (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      core_en,
    input  logic                      calib_done,
    // Instruction cache
    input  logic                      ic_req_valid,
    input  logic [          XLEN-1:0] ic_req_addr,
    output logic [      LineBits-1:0] ic_resp_rdata,
    output logic                      ic_resp_ready,
    // Data cache
    input  logic                      dc_req_valid,
    input  logic                      dc_req_rw,
    input  logic [          XLEN-1:0] dc_req_addr,
    input  logic [      LineBits-1:0] dc_req_wdata,
    output logic [      LineBits-1:0] dc_resp_rdata,
    output logic                      dc_resp_ready,
    // Boot
    input  logic                      boot_we,
    input  logic [          XLEN-1:0] boot_addr,
    input  logic [          XLEN-1:0] boot_wdata,
    // Controller command
    output logic [APP_ADDR_WIDTH-1:0] app_addr,
    output logic [               2:0] app_cmd,
    output logic                      app_en,
    input  logic                      app_rdy,
    // Controller write data
    output logic [      LineBits-1:0] app_wdf_data,
    output logic [      MaskBits-1:0] app_wdf_mask,      // 1 = supress write, 0 = write
    output logic                      app_wdf_wren,
    output logic                      app_wdf_end,
    input  logic                      app_wdf_rdy,
    // Controller read data
    input  logic [      LineBits-1:0] app_rd_data,
    input  logic                      app_rd_data_valid
`ifdef RISCV_FORMAL
    ,
    output logic [               1:0] dbg_state,
    output logic [               1:0] dbg_src,
    output logic                      dbg_cmd_done,
    output logic                      dbg_wdf_done,
    output logic                      dbg_resp_pending,
    output logic                      dbg_req_rw
`endif
);

  localparam logic [2:0] AppWrite = 3'b000;
  localparam logic [2:0] AppRead = 3'b001;
  localparam logic ReqRead = 1'b0;
  localparam logic ReqWrite = 1'b1;

  typedef enum logic [1:0] {
    IDLE,
    ISSUE,
    WAIT_RESP
  } state_t;

  typedef enum logic [1:0] {
    SRC_IC,
    SRC_DC,
    SRC_BOOT
  } src_t;

  state_t state, next_state;
  src_t                src;

  logic                cmd_done;  // Command handshake done
  logic                wdf_done;  // Write data handshake done
  logic                resp_done;  // Response delivered

  logic [    XLEN-1:0] req_addr;
  logic [LineBits-1:0] req_wdata;
  logic [MaskBits-1:0] req_mask;
  logic                req_rw;

  logic [LineBits-1:0] resp_data;
  logic                resp_pending;

  always_ff @(posedge clk) begin
    app_en <= 1'b0;
    app_wdf_wren <= 1'b0;
    app_wdf_end <= 1'b0;
    if (!rst_n) begin
      state <= IDLE;
      resp_pending <= 1'b0;
      cmd_done <= 1'b0;
      wdf_done <= 1'b0;
    end else if (calib_done) begin
      state <= next_state;
      case (state)
        IDLE: begin
          // Latch request (priority: boot > dcache > icache)
          if (core_en) begin
            cmd_done <= 1'b0;
            wdf_done <= 1'b0;
            if (boot_we) begin
              src <= SRC_BOOT;
              req_rw <= ReqWrite;
              req_addr <= boot_addr;
              req_wdata <= {4{boot_wdata}};
              req_mask <= ~(16'hF << {boot_addr[3:2], 2'b00});  // Only open selected word
            end else if (dc_req_valid) begin
              src <= SRC_DC;
              req_rw <= dc_req_rw;
              req_addr <= dc_req_addr;
              req_wdata <= dc_req_wdata;
              req_mask <= '0;
            end else if (ic_req_valid) begin
              src <= SRC_IC;
              req_rw <= ReqRead;
              req_addr <= ic_req_addr;
            end
          end
        end
        ISSUE: begin
          // Latch newest values
          if (!cmd_done) begin
            app_addr <= {req_addr[APP_ADDR_WIDTH-1:4], 4'h0};
            app_cmd <= req_rw ? AppWrite : AppRead;
            app_wdf_data <= req_wdata;
            app_wdf_mask <= req_mask;
          end

          // Command handshake
          if (!cmd_done) begin
            if (app_en && app_rdy) cmd_done <= 1'b1;
            else app_en <= 1'b1;
          end
          // Write data handshake
          if (!wdf_done) begin
            if (app_wdf_wren && app_wdf_rdy) wdf_done <= 1'b1;
            else begin
              app_wdf_wren <= req_rw;
              app_wdf_end  <= req_rw;
            end
          end
        end
        WAIT_RESP: begin
          if (app_rd_data_valid) begin
            resp_data <= app_rd_data;
            resp_pending <= 1'b1;
          end
          if (resp_done) resp_pending <= 1'b0;
        end
        default: ;
      endcase
    end
  end

  always_comb begin
    next_state    = state;
    ic_resp_ready = 1'b0;
    dc_resp_ready = 1'b0;
    resp_done     = 1'b0;
    case (state)
      IDLE: if ((boot_we || dc_req_valid || ic_req_valid) && core_en) next_state = ISSUE;
      ISSUE:
      if ((cmd_done || (app_en && app_rdy)) &&
          ((req_rw == ReqRead) || wdf_done || (app_wdf_wren && app_wdf_rdy)))
        next_state = WAIT_RESP;
      WAIT_RESP: begin
        if (core_en && (resp_pending || (req_rw == ReqWrite))) begin
          case (src)
            SRC_IC:   ic_resp_ready = 1'b1;
            SRC_DC:   dc_resp_ready = 1'b1;
            SRC_BOOT: ;
            default:  ;
          endcase
          resp_done = 1'b1;
        end
        if (resp_done) next_state = IDLE;
      end
      default: ;
    endcase
  end

  assign ic_resp_rdata = resp_data;
  assign dc_resp_rdata = resp_data;

`ifdef RISCV_FORMAL
  assign dbg_state = state;
  assign dbg_src = src;
  assign dbg_cmd_done = cmd_done;
  assign dbg_wdf_done = wdf_done;
  assign dbg_resp_pending = resp_pending;
  assign dbg_req_rw = req_rw;
`endif

endmodule
