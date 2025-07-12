`timescale 1ns / 1ps

module addition_core #(
    parameter FMS_PATCH_SIZE = 8,
    parameter KERNEL_SIZE = 3,
    parameter INFMS_DATA_WIDTH = 8,
    parameter KERNEL_DATA_WIDTH = 4,
    parameter CORE_NUM = 18
) (
    input clk,
    input rst_n,
    input infms_data_vld,
    input logic signed [FMS_PATCH_SIZE*FMS_PATCH_SIZE*INFMS_DATA_WIDTH-1:0] in_fm,
    input logic signed [KERNEL_DATA_WIDTH -1:0] kernel_x[KERNEL_SIZE * KERNEL_SIZE - 1:0],
    input logic signed [KERNEL_DATA_WIDTH -1:0] kernel_y[KERNEL_SIZE * KERNEL_SIZE - 1:0],
    output logic signed [FMS_PATCH_SIZE*FMS_PATCH_SIZE*OUT_DATA_WIDTH-1:0] out_fm
);
  localparam MULTIPLIED_DATA_WIDTH = INFMS_DATA_WIDTH + KERNEL_DATA_WIDTH;
  localparam OUT_DATA_WIDTH = MULTIPLIED_DATA_WIDTH + $clog2(CORE_NUM);

  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_11 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_12 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_21 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_22 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_31 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_32 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_41 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_42 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_51 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_52 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_61 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_62 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_71 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_72 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_81 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_82 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_91 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];
  logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_92 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];

  logic signed [OUT_DATA_WIDTH-1 : 0] adder_tree_output[FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0];

  // Instantiate multiplication_core
  multiplication_core #(
      .FMS_PATCH_SIZE(FMS_PATCH_SIZE),
      .INFMS_DATA_WIDTH(INFMS_DATA_WIDTH),
      .KERNEL_SIZE(KERNEL_SIZE),
      .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH)
  ) multiplication_inst (
      .clk(clk),
      .rst_n(rst_n),
      .clk_en(infms_data_vld),
      .infms_data_vld(infms_data_vld),

      .infms_data(in_fm),
      .kernel_x  (kernel_x),
      .kernel_y  (kernel_y),

      .multiplied_data_mat_11(multiplied_data_mat_11),
      .multiplied_data_mat_12(multiplied_data_mat_12),
      .multiplied_data_mat_21(multiplied_data_mat_21),
      .multiplied_data_mat_22(multiplied_data_mat_22),
      .multiplied_data_mat_31(multiplied_data_mat_31),
      .multiplied_data_mat_32(multiplied_data_mat_32),
      .multiplied_data_mat_41(multiplied_data_mat_41),
      .multiplied_data_mat_42(multiplied_data_mat_42),
      .multiplied_data_mat_51(multiplied_data_mat_51),
      .multiplied_data_mat_52(multiplied_data_mat_52),
      .multiplied_data_mat_61(multiplied_data_mat_61),
      .multiplied_data_mat_62(multiplied_data_mat_62),
      .multiplied_data_mat_71(multiplied_data_mat_71),
      .multiplied_data_mat_72(multiplied_data_mat_72),
      .multiplied_data_mat_81(multiplied_data_mat_81),
      .multiplied_data_mat_82(multiplied_data_mat_82),
      .multiplied_data_mat_91(multiplied_data_mat_91),
      .multiplied_data_mat_92(multiplied_data_mat_92)
  );

  genvar h, w;
  generate
    for (h = 0; h < FMS_PATCH_SIZE; h = h + 1) begin : gen_adder_tree_h
      for (w = 0; w < FMS_PATCH_SIZE; w = w + 1) begin : gen_adder_tree_w
        adder_tree #(
            .INPUT_NUM(CORE_NUM),
            .INPUT_DATA_WIDTH(MULTIPLIED_DATA_WIDTH)
        ) adder_tree_inst (
            .clk(clk),
            .rst_n(rst_n),
            .din({
              multiplied_data_mat_11[h][w],
              multiplied_data_mat_12[h][w],
              multiplied_data_mat_21[h][w],
              multiplied_data_mat_22[h][w],
              multiplied_data_mat_31[h][w],
              multiplied_data_mat_32[h][w],
              multiplied_data_mat_41[h][w],
              multiplied_data_mat_42[h][w],
              multiplied_data_mat_51[h][w],
              multiplied_data_mat_52[h][w],
              multiplied_data_mat_61[h][w],
              multiplied_data_mat_62[h][w],
              multiplied_data_mat_71[h][w],
              multiplied_data_mat_72[h][w],
              multiplied_data_mat_81[h][w],
              multiplied_data_mat_82[h][w],
              multiplied_data_mat_91[h][w],
              multiplied_data_mat_92[h][w]
            }),
            .dout(adder_tree_output[h][w])
        );
        assign out_fm[(h*FMS_PATCH_SIZE+w+1)*OUT_DATA_WIDTH-1-:OUT_DATA_WIDTH] = adder_tree_output[h][w];
      end
    end
  endgenerate

endmodule
