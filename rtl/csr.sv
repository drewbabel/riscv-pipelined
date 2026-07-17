module csr
  import csr_pkg::*;
#(
    parameter int XLEN = 32
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,

    // Zicsr access
    input logic            csr_access,
    input logic [    11:0] csr_addr,
    input logic [     2:0] funct3,
    input logic [XLEN-1:0] rs1_data,
    input logic [     4:0] zimm,

    // Trapped-instruction context
    input logic [XLEN-1:0] pc,
    input logic [XLEN-1:0] bad_addr,

    // Exception sources
    input logic exc_illegal,
    input logic exc_ecall,
    input logic exc_ebreak,
    input logic exc_instr_misaligned,
    input logic exc_load_misaligned,
    input logic exc_store_misaligned,

    // Interrupt from CLINT
    input logic is_mret,
    input logic timer_irq,

    // Zicsr read value to writeback mux
    output logic [XLEN-1:0] csr_rdata,

    // Redirects into pc next-address mux
    output logic            trap_taken,
    output logic [XLEN-1:0] trap_vector,
    output logic            mret_taken,
    output logic [XLEN-1:0] mepc_out
`ifdef RISCV_FORMAL
    ,
    output logic [XLEN-1:0] dbg_csr_wdata,
    output logic [XLEN-1:0] dbg_mscratch,
    output logic [XLEN-1:0] dbg_mstatus,
    output logic [XLEN-1:0] dbg_mtvec,
    output logic [XLEN-1:0] dbg_mepc,
    output logic [XLEN-1:0] dbg_mcause,
    output logic [XLEN-1:0] dbg_mtval,
    output logic [XLEN-1:0] dbg_mie,
    output logic [XLEN-1:0] dbg_mip,
    output logic [XLEN-1:0] dbg_mcycle,
    output logic [XLEN-1:0] dbg_minstret,
    output logic [XLEN-1:0] dbg_mcycleh,
    output logic [XLEN-1:0] dbg_minstreth
`endif
);

  logic [XLEN-1:0] mstatus;
  logic [XLEN-1:0] mtvec;
  logic [XLEN-1:0] mepc;
  logic [XLEN-1:0] mcause;
  logic [XLEN-1:0] mtval;
  logic [XLEN-1:0] mie;
  logic [XLEN-1:0] mip;
  logic [XLEN-1:0] mscratch;
  logic [XLEN-1:0] mcycle;
  logic [XLEN-1:0] minstret;
  logic [XLEN-1:0] mcycleh;
  logic [XLEN-1:0] minstreth;

  logic [XLEN-1:0] csr_wsrc;
  logic [XLEN-1:0] csr_wdata;
  logic            csr_write_en;

  assign csr_wsrc = (funct3[2]) ? {{(XLEN - 5) {1'b0}}, zimm} : rs1_data;
  always_comb begin
    case (funct3)
      Funct3Csrrw, Funct3Csrrwi: csr_wdata = csr_wsrc;
      Funct3Csrrs, Funct3Csrrsi: csr_wdata = csr_rdata | csr_wsrc;
      Funct3Csrrc, Funct3Csrrci: csr_wdata = csr_rdata & ~csr_wsrc;
      default:                   csr_wdata = csr_rdata;
    endcase
  end
  assign trap_taken  = exc_illegal | exc_ecall | exc_ebreak | exc_instr_misaligned
                        | exc_load_misaligned | exc_store_misaligned
                        | (timer_irq & mstatus[MstatusMie] & mie[Mtie]);
  // Reject if trap, or if set/clear with zero source
  assign csr_write_en = csr_access && !trap_taken && 
                        !((funct3[1:0] == 2'b10 || funct3[1:0] == 2'b11) && (csr_wsrc == '0));
  assign trap_vector = {mtvec[31:2], 2'b00};  // Divide by 4 = remove last 2 bits
  assign mret_taken = is_mret;
  assign mepc_out = mepc;

  // Mtip mirrors line
  logic [XLEN-1:0] mip_read;
  always_comb begin
    mip_read = mip;
    mip_read[Mtip] = timer_irq;
  end

  // Read mux
  always_comb begin
    case (csr_addr)
      MstatusAddr:  csr_rdata = mstatus;
      MieAddr:      csr_rdata = mie;
      MtvecAddr:    csr_rdata = mtvec;
      MscratchAddr: csr_rdata = mscratch;
      MepcAddr:     csr_rdata = mepc;
      McauseAddr:   csr_rdata = mcause;
      MtvalAddr:    csr_rdata = mtval;
      MipAddr:      csr_rdata = mip_read;
      McycleAddr:   csr_rdata = mcycle;
      MinstretAddr: csr_rdata = minstret;
      McyclehAddr:   csr_rdata = mcycleh;
      MinstrethAddr: csr_rdata = minstreth;
      default:      csr_rdata = '0;
    endcase
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      mstatus  <= '0;
      mtvec    <= '0;
      mepc     <= '0;
      mcause   <= '0;
      mtval    <= '0;
      mie      <= '0;
      mip      <= '0;
      mscratch <= '0;
      mcycle   <= '0;
      minstret <= '0;
      mcycleh   <= '0;
      minstreth <= '0;
    end else if (core_en) begin
      mcycle  <= mcycle + 1;
      mcycleh <= (mcycle == '1) ? mcycleh + 1 : mcycleh;
      if (!trap_taken) begin  // retired only
        minstret  <= minstret + 1;
        minstreth <= (minstret == '1) ? minstreth + 1 : minstreth;
      end

      if (trap_taken) begin
        mstatus[MstatusMpie] <= mstatus[MstatusMie];
        mstatus[MstatusMie]  <= 1'b0;
        mepc <= pc;
        if (exc_instr_misaligned) begin
          mcause <= {1'b0, 31'(CauseInstrMisaligned)};
          mtval  <= bad_addr;
        end else if (exc_illegal) begin
          mcause <= {1'b0, 31'(CauseIllegalInstr)};
          mtval  <= '0;
        end else if (exc_ecall) begin
          mcause <= {1'b0, 31'(CauseEcallM)};
          mtval  <= '0;
        end else if (exc_ebreak) begin
          mcause <= {1'b0, 31'(CauseBreakpoint)};
          mtval  <= '0;
        end else if (exc_load_misaligned) begin
          mcause <= {1'b0, 31'(CauseLoadMisaligned)};
          mtval  <= bad_addr;
        end else if (exc_store_misaligned) begin
          mcause <= {1'b0, 31'(CauseStoreMisaligned)};
          mtval  <= bad_addr;
        end else begin
          mcause <= {1'b1, 31'(CauseMachineTimerIrq)};
          mtval  <= '0;
        end
      end else if (is_mret) begin
        mstatus[MstatusMie]  <= mstatus[MstatusMpie];
        mstatus[MstatusMpie] <= 1'b1;
      end

      if (csr_write_en) begin
        case (csr_addr)
          MstatusAddr:  mstatus <= csr_wdata;
          MieAddr:      mie <= csr_wdata;
          MtvecAddr:    mtvec <= csr_wdata;
          MscratchAddr: mscratch <= csr_wdata;
          MepcAddr:     mepc <= csr_wdata;
          McauseAddr:   mcause <= csr_wdata;
          MtvalAddr:    mtval <= csr_wdata;
          MipAddr:      mip <= csr_wdata & ~(XLEN'(1) << Mtip);  // Mtip read-only
          McycleAddr:   mcycle <= csr_wdata;
          MinstretAddr: minstret <= csr_wdata;
          McyclehAddr:   mcycleh <= csr_wdata;
          MinstrethAddr: minstreth <= csr_wdata;
          default:      ;
        endcase
      end
    end
  end

`ifdef RISCV_FORMAL
  assign dbg_csr_wdata = csr_wdata;
  assign dbg_mscratch  = mscratch;
  assign dbg_mstatus   = mstatus;
  assign dbg_mtvec     = mtvec;
  assign dbg_mepc      = mepc;
  assign dbg_mcause    = mcause;
  assign dbg_mtval     = mtval;
  assign dbg_mie       = mie;
  assign dbg_mip       = mip;
  assign dbg_mcycle    = mcycle;
  assign dbg_minstret  = minstret;
  assign dbg_mcycleh   = mcycleh;
  assign dbg_minstreth = minstreth;
`endif
endmodule
