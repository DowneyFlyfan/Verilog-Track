`timescale 1ns / 1ps

// TODO:考虑做一个两行的加法器, 空间极致利用, 但取index可能慢点
// TODO:或者做一个 n -> n/2 * log2(n) 的加法器，可以省近一半的空间
module adder_tree #(
    parameter INPUT_NUM,
    parameter IN_WIDTH
) (
    input logic clk,
    input logic rst_n,
    input logic add_en,
    input logic signed [INPUT_NUM*IN_WIDTH-1 : 0] din,
    output logic signed [OUT_WIDTH-1 : 0] dout
);
  localparam OUT_WIDTH = IN_WIDTH + $clog2(INPUT_NUM);
  localparam STAGE_NUM = $clog2(INPUT_NUM);
  localparam INPUT_NUM_INIT = 2 ** STAGE_NUM;

  logic signed [OUT_WIDTH-1 : 0] adder_tree_data[STAGE_NUM : 0][INPUT_NUM_INIT-1 : 0];

  // reset或者重新装填
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int adder = 0; adder < INPUT_NUM_INIT; adder = adder + 1) begin
        adder_tree_data[0][adder] <= '0;
      end
    end else if (add_en) begin
      for (int adder = 0; adder < INPUT_NUM_INIT; adder = adder + 1) begin
        if (adder < INPUT_NUM) begin
          adder_tree_data[0][adder] <= signed'(din[(adder+1)*IN_WIDTH-1-:IN_WIDTH]);
        end else begin
          adder_tree_data[0][adder] <= '0;
        end
      end
    end
  end

  // Pipelined adder stages
  genvar stage;
  generate
    for (stage = 1; stage <= STAGE_NUM; stage = stage + 1) begin
      localparam CRNT_STAGE_NUM = INPUT_NUM_INIT >> stage;
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (int adder = 0; adder < CRNT_STAGE_NUM; adder = adder + 1) begin
            adder_tree_data[stage][adder] <= '0;
          end
        end else if (add_en) begin
          begin
            for (int adder = 0; adder < CRNT_STAGE_NUM; adder = adder + 1) begin
              adder_tree_data[stage][adder] <= adder_tree_data[stage-1][adder*2] + adder_tree_data[stage-1][adder*2+1];
            end
          end
        end
      end
    end
    assign dout = adder_tree_data[STAGE_NUM][0];
  endgenerate
endmodule
