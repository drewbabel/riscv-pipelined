module synchronizer (
    input  logic clk,
    input  logic core_en,
    input  logic d,
    output logic q
);

  logic ff;

  always_ff @(posedge clk)
    if (core_en) begin
      ff <= d;
      q  <= ff;
    end

endmodule
