`timescale 1ns / 1ps

// NOTE: 当前测试Sobel卷积
module tb_convolution_core;

  // Parameters
  localparam ROI_SIZE = 48;
  localparam PORT_BITS = 128;
  localparam CHANNEL_ADD_VLD = 1;
  localparam CLK_PERIOD = 10;

  localparam IN_WIDTH = 8;
  localparam KERNEL_DATA_WIDTH = 4;
  localparam CORE_NUM = 18;
  localparam OUT_WIDTH = IN_WIDTH + KERNEL_DATA_WIDTH + $clog2(CORE_NUM);

  localparam KERNEL_SIZE = 3;
  localparam PAD_SIZE = (KERNEL_SIZE - 1) / 2;
  localparam KERNEL_NUM = 2;
  localparam KERNEL_AREA = KERNEL_SIZE * KERNEL_SIZE;
  localparam NUM_PER_CYCLE = PORT_BITS / IN_WIDTH;
  localparam ADDER_LATENCY = $clog2(KERNEL_AREA * KERNEL_NUM) + 1;
  localparam TOTAL_CYCLES = ADDER_LATENCY + (ROI_SIZE * (ROI_SIZE + KERNEL_SIZE - PAD_SIZE)) / NUM_PER_CYCLE;

  // Signals
  logic clk;
  logic clk_en;
  logic conv_en;
  logic rst_n;

  // Memory for file I/O
  reg signed [KERNEL_DATA_WIDTH-1:0] kernel_vec[KERNEL_NUM*KERNEL_SIZE*KERNEL_SIZE-1:0];
  reg signed [IN_WIDTH-1:0] in_img[ROI_SIZE*ROI_SIZE-1:0];

  // DUT I/O
  logic signed [KERNEL_DATA_WIDTH-1:0] kernel_mat[KERNEL_NUM-1:0][KERNEL_SIZE-1:0][KERNEL_SIZE-1:0];
  logic signed [PORT_BITS-1:0] din;
  logic signed [OUT_WIDTH-1:0] dout[KERNEL_NUM-1:0][NUM_PER_CYCLE - 1:0];
  logic signed [OUT_WIDTH-1:0] out_img[ROI_SIZE*ROI_SIZE-1:0];
  logic conv_out_vld;

  convolution_core #(
      .ROI_SIZE(ROI_SIZE),
      .PORT_BITS(PORT_BITS),
      .IN_WIDTH(IN_WIDTH),
      .KERNEL_SIZE(KERNEL_SIZE),
      .KERNEL_DATA_WIDTH(KERNEL_DATA_WIDTH),
      .KERNEL_NUM(KERNEL_NUM),
      .CHANNEL_ADD_VLD(CHANNEL_ADD_VLD)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .clk_en(clk_en),
      .conv_en(conv_en),
      .data_in(din),
      .kernel(kernel_mat),
      .data_out(dout),
      .conv_out_vld(conv_out_vld)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Connect kernels
  genvar n, h, w;
  generate
    for (n = 0; n < KERNEL_NUM; n = n + 1) begin
      for (h = 0; h < KERNEL_SIZE; h = h + 1) begin
        for (w = 0; w < KERNEL_SIZE; w = w + 1) begin
          assign kernel_mat[n][h][w] = kernel_vec[n*KERNEL_AREA+h*KERNEL_SIZE+w];
        end
      end
    end
  endgenerate

  // Main process to drive inputs, control simulation, and handle outputs
  initial begin
    int in_pixel_idx = 0;
    int out_pixel_idx = 0;

    // 1. Initialize signals and load data
    rst_n = 1'b1;
    clk_en = 1'b0;
    conv_en = 1'b0;
    din = '0;

    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\input_img.txt", in_img);
    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\kernel.txt", kernel_vec);

    repeat (1) @(negedge clk);
    conv_en = 1'b1;
    clk_en  = 1'b1;

    repeat (1) @(negedge clk);
    rst_n = 1'b1;

    while (out_pixel_idx < ROI_SIZE * ROI_SIZE) begin
      @(posedge clk);
      // Drive inputs as long as there is data
      if (in_pixel_idx < ROI_SIZE * ROI_SIZE) begin
        for (int i = 0; i < NUM_PER_CYCLE; i++) begin
          din[(i+1)*IN_WIDTH-1-:IN_WIDTH] = in_img[in_pixel_idx+i];
        end
        in_pixel_idx = in_pixel_idx + NUM_PER_CYCLE;
      end else begin
        din = '0;  // Drive zeros after all input data is sent
      end

      // Capture outputs when valid
      if (conv_out_vld) begin
        for (int i = 0; i < NUM_PER_CYCLE; i++) begin
          out_img[out_pixel_idx+i] = dout[0][i];
        end
        out_pixel_idx = out_pixel_idx + NUM_PER_CYCLE;
      end
    end

    // 4. Write output and finish simulation
    #1;
    $writememh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\output_img.txt", out_img);
    $display("Output written to output_img.txt! Finishing simulation.");
    $finish;
  end

endmodule
