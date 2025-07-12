`timescale 1ns / 1ps

// NOTE: 当前测试Sobel卷积
module tb_convolution_core;

  // Parameters
  localparam ROI_SIZE = 480;
  localparam PORT_BITS = 128;
  localparam CHANNEL_ADD_VLD = 1;

  localparam IN_WIDTH = 8;
  localparam KERNEL_DATA_WIDTH = 4;
  localparam CORE_NUM = 18;
  localparam OUT_WIDTH = IN_WIDTH + KERNEL_DATA_WIDTH + $clog2(CORE_NUM);

  localparam KERNEL_SIZE = 3;
  localparam KERNEL_NUM = 2;
  localparam KERNEL_AREA = KERNEL_SIZE * KERNEL_SIZE;
  localparam NUM_PER_CYCLE = PORT_BITS / IN_WIDTH;

  // Signals
  logic clk;
  logic clk_en;
  logic conv_en;
  logic rst_n;
  logic infms_data_vld = 1'b1;

  // Memory for file I/O
  reg signed [KERNEL_DATA_WIDTH-1:0] kernel_vec[KERNEL_NUM*KERNEL_SIZE*KERNEL_SIZE-1:0];
  reg signed [IN_WIDTH-1:0] in_img[ROI_SIZE*ROI_SIZE-1:0];

  // DUT I/O
  logic signed [KERNEL_DATA_WIDTH-1:0] kernel_mat[KERNEL_NUM-1:0][KERNEL_SIZE-1:0][KERNEL_SIZE-1:0];
  logic signed [PORT_BITS-1:0] din;
  logic signed [OUT_WIDTH-1:0] dout[KERNEL_NUM-1:0][NUM_PER_CYCLE - 1:0];
  logic signed [OUT_WIDTH-1:0] out_img[ROI_SIZE*ROI_SIZE-1:0];
  logic data_out_vld;

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
      .data_out_vld(data_out_vld)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
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
    // 1. Initialize signals and load data
    rst_n = 1'b0;
    clk_en = 1'b0;
    conv_en = 1'b0;
    din = '0;

    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\input_img.txt", in_img);
    $readmemh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\kernel.txt", kernel_vec);

    // 2. Apply and release reset
    #10;
    rst_n = 1'b1;
    @(posedge clk);

    // 3. Start convolution and use fork...join to handle I/O in parallel
    clk_en  = 1'b1;
    conv_en = 1'b1;

    fork
      // Process 1: Drive inputs
      begin
        for (
            int pixel_idx = 0;
            pixel_idx < (ROI_SIZE * ROI_SIZE);
            pixel_idx = pixel_idx + NUM_PER_CYCLE
        ) begin
          @(posedge clk);
          for (int i = 0; i < NUM_PER_CYCLE; i++) begin
            din[(i+1)*IN_WIDTH-1-:IN_WIDTH] = in_img[pixel_idx+i];
          end
        end
        // After last input, drive zeros for a while to flush the pipeline
        @(posedge clk);
        din = '0;
      end

      // Process 2: Capture outputs based on valid signal
      begin
        int captured_pixels = 0;
        while (captured_pixels < ROI_SIZE * ROI_SIZE) begin
          @(posedge clk);
          if (data_out_vld) begin
            for (int i = 0; i < NUM_PER_CYCLE; i++) begin
              if (captured_pixels + i < ROI_SIZE * ROI_SIZE) begin
                out_img[captured_pixels + i] = dout[0][i];
              end
            end
            captured_pixels = captured_pixels + NUM_PER_CYCLE;
          end
        end

        // 4. All pixels captured. Wait a bit more for safety.
        repeat (100) @(posedge clk);
        clk_en = 1'b0;

        // 5. Write output and finish simulation
        #1;
        $writememh("D:\\Vivado\\Vivado_Projects\\Conv\\Codes\\texts\\output_img.txt", out_img);
        $display("Output written. Finishing simulation.");
        $finish;
      end
    join
  end

endmodule
