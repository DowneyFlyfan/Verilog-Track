`timescale 1ns / 1ps

// TODO: 只有2个通道，放在加法树里做18个数的相加 还是放在这里直接加?
// 18个中间数据能不能合并成一个???
module multiplication_core #(
    parameter FMS_PATCH_SIZE,
    parameter INFMS_DATA_WIDTH,
    parameter KERNEL_DATA_WIDTH,
    parameter KERNEL_SIZE,
    parameter KERNEL_NUM
) (
    input clk,
    input rst_n,
    input clk_en,
    input infms_data_vld,

    input logic signed [INFMS_DATA_WIDTH * FMS_PATCH_SIZE * FMS_PATCH_SIZE -1 : 0] infms_data,
    input logic signed [KERNEL_DATA_WIDTH -1:0] kernel_x[KERNEL_SIZE * KERNEL_SIZE - 1:0],
    input logic signed [KERNEL_DATA_WIDTH -1:0] kernel_y[KERNEL_SIZE * KERNEL_SIZE - 1:0],

    // dd - CORE_Index, Channel_Index
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_11 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_12 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_21 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_22 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_31 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_32 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_41 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_42 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_51 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_52 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_61 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_62 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_71 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_72 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_81 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_82 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_91 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0],
    output logic signed [MULTIPLIED_DATA_WIDTH-1 : 0] multiplied_data_mat_92 [FMS_PATCH_SIZE-1 : 0][FMS_PATCH_SIZE-1 : 0]
);
  logic signed [INFMS_DATA_WIDTH-1 : 0] padded_infms[FMS_PATCH_SIZE+1:0][FMS_PATCH_SIZE+1:0];
  localparam MULTIPLIED_DATA_WIDTH = INFMS_DATA_WIDTH + KERNEL_DATA_WIDTH;

  // Pad Inputs
  genvar h, w;
  generate
    for (h = 0; h < FMS_PATCH_SIZE + 2; h = h + 1) begin
      for (w = 0; w < FMS_PATCH_SIZE + 2; w = w + 1) begin
        if (h == 0 || h == FMS_PATCH_SIZE + 1 || w == 0 || w == FMS_PATCH_SIZE + 1) begin
          assign padded_infms[h][w] = '0;
        end else begin
          assign padded_infms[h][w] = infms_data[((h-1)*FMS_PATCH_SIZE+w)*INFMS_DATA_WIDTH-1-:INFMS_DATA_WIDTH];
        end
      end
    end
  endgenerate


  // TODO: multiplied_data_vld 考虑一下怎么用?
  integer height, width;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (height = 0; height < FMS_PATCH_SIZE; height = height + 1) begin
        for (width = 0; width < FMS_PATCH_SIZE; width = width + 1) begin
          multiplied_data_mat_11[height][width] <= '0;
          multiplied_data_mat_12[height][width] <= '0;
          multiplied_data_mat_21[height][width] <= '0;
          multiplied_data_mat_22[height][width] <= '0;
          multiplied_data_mat_31[height][width] <= '0;
          multiplied_data_mat_32[height][width] <= '0;
          multiplied_data_mat_41[height][width] <= '0;
          multiplied_data_mat_42[height][width] <= '0;
          multiplied_data_mat_51[height][width] <= '0;
          multiplied_data_mat_52[height][width] <= '0;
          multiplied_data_mat_61[height][width] <= '0;
          multiplied_data_mat_62[height][width] <= '0;
          multiplied_data_mat_71[height][width] <= '0;
          multiplied_data_mat_72[height][width] <= '0;
          multiplied_data_mat_81[height][width] <= '0;
          multiplied_data_mat_82[height][width] <= '0;
          multiplied_data_mat_91[height][width] <= '0;
          multiplied_data_mat_92[height][width] <= '0;
        end
      end
    end else if (clk_en) begin
      if (infms_data_vld) begin
        for (height = 0; height < FMS_PATCH_SIZE; height = height + 1) begin
          for (width = 0; width < FMS_PATCH_SIZE; width = width + 1) begin
            multiplied_data_mat_11[height][width] <= padded_infms[height][width] * kernel_x[0];
            multiplied_data_mat_12[height][width] <= padded_infms[height][width] * kernel_y[0];

            multiplied_data_mat_21[height][width] <= padded_infms[height][width+1] * kernel_x[1];
            multiplied_data_mat_22[height][width] <= padded_infms[height][width+1] * kernel_y[1];

            multiplied_data_mat_31[height][width] <= padded_infms[height][width+2] * kernel_x[2];
            multiplied_data_mat_32[height][width] <= padded_infms[height][width+2] * kernel_y[2];

            multiplied_data_mat_41[height][width] <= padded_infms[height+1][width] * kernel_x[3];
            multiplied_data_mat_42[height][width] <= padded_infms[height+1][width] * kernel_y[3];

            multiplied_data_mat_51[height][width] <= padded_infms[height+1][width+1] * kernel_x[4];
            multiplied_data_mat_52[height][width] <= padded_infms[height+1][width+1] * kernel_y[4];

            multiplied_data_mat_61[height][width] <= padded_infms[height+1][width+2] * kernel_x[5];
            multiplied_data_mat_62[height][width] <= padded_infms[height+1][width+2] * kernel_y[5];

            multiplied_data_mat_71[height][width] <= padded_infms[height+2][width] * kernel_x[6];
            multiplied_data_mat_72[height][width] <= padded_infms[height+2][width] * kernel_y[6];

            multiplied_data_mat_81[height][width] <= padded_infms[height+2][width+1] * kernel_x[7];
            multiplied_data_mat_82[height][width] <= padded_infms[height+2][width+1] * kernel_y[7];

            multiplied_data_mat_91[height][width] <= padded_infms[height+2][width+2] * kernel_x[8];
            multiplied_data_mat_92[height][width] <= padded_infms[height+2][width+2] * kernel_y[8];
          end
        end
      end
    end
  end
endmodule
