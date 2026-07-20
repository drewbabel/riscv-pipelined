module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200,
    parameter int DATA_BITS   = 8
) (
    input logic clk,
    input logic core_en,
    input logic rst_n,
    input logic [DATA_BITS-1:0] tx_data,
    input logic tx_valid,
    output logic tx_ready,
    output logic tx_serial
);

  localparam int ClksPerBit = (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;

  typedef enum logic [1:0] {
    IDLE,
    START,
    DATA,
    STOP
  } state_t;

  state_t state, next_state;
  logic tick;
  logic tick_clr;
  logic [DATA_BITS-1:0] data;
  logic [$clog2(DATA_BITS):0] data_cnt;

  tick_gen #(
      .DIVISOR(ClksPerBit)
  ) oversample_tick (
      .clk    (clk),
      .core_en(core_en),
      .rst_n  (rst_n),
      .clr    (tick_clr),
      .tick   (tick)
  );

  always_ff @(posedge clk)
    if (core_en) begin
      if (!rst_n) begin
        state <= IDLE;
        tx_serial <= 1'b1;
        data_cnt <= '0;
      end else begin
        state <= next_state;
        if (tx_valid && tx_ready) data <= tx_data;

        case (state)
          START: begin
            tx_serial <= 1'b0;
            data_cnt  <= '0;
          end

          DATA: begin
            tx_serial <= data[0];
            if (tick) begin
              data <= data >> 1;
              data_cnt <= data_cnt + 1'b1;
            end
          end

          STOP: tx_serial <= 1'b1;
          default: data_cnt <= '0;
        endcase
      end
    end

  always_comb begin
    next_state = state;
    tx_ready   = 1'b0;

    case (state)
      IDLE: begin
        if (rst_n) tx_ready = 1'b1;
        if (tx_valid && tx_ready) next_state = START;
      end

      START: if (tick) next_state = DATA;

      DATA:
      if (data_cnt == $bits(data_cnt)'(DATA_BITS - 1)) begin
        if (tick) next_state = STOP;
      end

      STOP:
      if (tick) begin
        tx_ready = 1'b1;
        if (tx_valid) next_state = START;
        else next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase

    if (!rst_n) tx_ready = 1'b0;
    tick_clr = (state != next_state) ? 1'b1 : 1'b0;
  end

endmodule
