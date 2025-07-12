`timescale 1ns / 1ps

module tb_convolution_core;

  // Parameters
  localparam FMS_PATCH_SIZE = 8;
  localparam KERNEL_SIZE = 3;
  localparam IN_DATA_WIDTH = 8;
  localparam KERNEL_DATA_WIDTH = 4;
  localparam CORE_NUM = 18;
  localparam MULTIPLIED_DATA_WIDTH = IN_DATA_WIDTH + KERNEL_DATA_WIDTH;
  localparam OUT_DATA_WIDTH = IN_DATA_WIDTH + KERNEL_DATA_WIDTH + $clog2(CORE_NUM);

  // Signals
  logic clk;
  logic rst_n;
  logic infms_data_vld = 1'b1;

  // Memory for file I/O (1D arrays)
  reg signed [IN_DATA_WIDTH-1:0] in_fm_mat[FMS_PATCH_SIZE*FMS_PATCH_SIZE-1:0];
  reg signed [KERNEL_DATA_WIDTH-1:0] kernel_x_mat[KERNEL_SIZE*KERNEL_SIZE-1:0];
  reg signed [KERNEL_DATA_WIDTH-1:0] kernel_y_mat[KERNEL_SIZE*KERNEL_SIZE-1:0];
  logic signed [OUT_DATA_WIDTH-1:0] out_fm_mat[FMS_PATCH_SIZE*FMS_PATCH_SIZE-1:0];

  // vectors
  logic signed [FMS_PATCH_SIZE*FMS_PATCH_SIZE*IN_DATA_WIDTH-1:0] in_fm_vec;
  logic signed [FMS_PATCH_SIZE*FMS_PATCH_SIZE*OUT_DATA_WIDTH-1:0] out_fm_vec;

  addition_core #(
      .FMS_PATCH_SIZE(FMS_PATCH_SIZE),
      .KERNEL_SIZE(KERNEL_SIZE),
      .INFMS_DATA_WIDTH(IN_DATA_WIDTH),
      .CORE_NUM(CORE_NUM),
      .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .in_fm(in_fm_vec),
      .infms_data_vld(infms_data_vld),
      .kernel_x(kernel_x_mat),
      .kernel_y(kernel_y_mat),
      .out_fm(out_fm_vec)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Procedural block for data marshalling
  genvar i;
  generate
    for (i = 0; i < FMS_PATCH_SIZE * FMS_PATCH_SIZE; i = i + 1) begin
      assign in_fm_vec[(i+1)*IN_DATA_WIDTH-1-:IN_DATA_WIDTH] = in_fm_mat[i];
      assign out_fm_mat[i] = out_fm_vec[(i+1)*OUT_DATA_WIDTH-1-:OUT_DATA_WIDTH];
    end
  endgenerate

  initial begin
    // Initialization and Reset
    rst_n = 0;

    // Load data from files, Read Memory Hexadecimal
    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\input_fm.txt", in_fm_mat);
    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\kernel_x.txt", kernel_x_mat);
    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\kernel_y.txt", kernel_y_mat);

    // Apply reset
    #10;
    rst_n = 1;

    // Start Conv
    repeat (8) @(posedge clk);
    $display("[%0t] Convolution finished. Capturing output.", $time);

    // Output
    #1;
    $writememh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\output_fm.txt", out_fm_mat);
    $display("Output written. Finishing simulation.");
    $finish;
  end
endmodule
