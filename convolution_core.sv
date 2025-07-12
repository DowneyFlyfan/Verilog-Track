// WARN:目前只考虑ROI_SIZE是NUM_PER_CYCLE的整数倍
module convolution_core #(
    parameter ROI_SIZE = 480,
    parameter PORT_BITS = 128,
    parameter IN_WIDTH = 8,
    parameter KERNEL_SIZE = 3,
    parameter KERNEL_DATA_WIDTH = 4,
    parameter KERNEL_NUM = 3,
    parameter CHANNEL_ADD_VLD = 1,
    parameter NUM_PER_CYCLE = PORT_BITS / IN_WIDTH
) (
    input clk,
    input rst_n,
    input clk_en,
    input conv_en,
    input logic signed [PORT_BITS - 1:0] data_in,
    input logic signed [KERNEL_DATA_WIDTH - 1:0] kernel[KERNEL_NUM-1:0][KERNEL_SIZE-1:0][KERNEL_SIZE-1:0],
    output logic signed [OUT_WIDTH-1:0] data_out[KERNEL_NUM-1:0][NUM_PER_CYCLE - 1:0],
    output logic data_out_vld
);

  // Params
  localparam KERNEL_AREA = KERNEL_SIZE * KERNEL_SIZE;
  localparam PAD_SIZE = (KERNEL_SIZE - 1) / 2;

  localparam BUF_WIDTH = ROI_SIZE + 2 * PAD_SIZE;
  localparam BUF_SIZE = BUF_WIDTH * KERNEL_SIZE;
  localparam PAD_AREA = PAD_SIZE * BUF_WIDTH;

  localparam FLAG_BITS = $clog2(KERNEL_SIZE);
  localparam HW_BITS = $clog2(ROI_SIZE);
  localparam BUF_BITS = $clog2(BUF_SIZE);
  localparam HEIGHT_BITS = $clog2(BUF_WIDTH * KERNEL_SIZE);

  localparam MULTIPLIED_WIDTH = IN_WIDTH + KERNEL_DATA_WIDTH;
  localparam OUT_WIDTH = (CHANNEL_ADD_VLD == 1) ? (MULTIPLIED_WIDTH + $clog2(
      KERNEL_AREA * KERNEL_NUM
  )) : (MULTIPLIED_WIDTH + $clog2(
      KERNEL_AREA
  ));

  // Buffers, Conv Matrix, Zeros
  logic signed [IN_WIDTH - 1:0] buffer[BUF_SIZE-1:0];
  logic signed [HEIGHT_BITS-1:0] BUF_WIDTH_MAT[KERNEL_SIZE-1:0];
  logic signed [MULTIPLIED_WIDTH-1:0] conv_mat[NUM_PER_CYCLE-1:0][KERNEL_NUM-1:0][KERNEL_AREA-1:0];
  logic [PORT_BITS-1:0] zeros = 0;

  // Indices
  logic [BUF_SIZE- 1:0] buf_idx, next_buf_idx;
  logic [HW_BITS-1:0] w_idx, h_idx, next_h_idx;  // Index for Conv Kernel on Top Left
  logic [FLAG_BITS-1:0] buf_flag;

  // State Machine
  localparam IDLE = 4'b1;
  localparam READ = 4'b10;
  localparam SIDE_CONV = 4'b100;
  localparam MIDDLE_CONV = 4'b1000;
  reg [3:0] n_state;
  reg [3:0] c_state;

  // Enable Signals
  logic add_en;
  logic read_en;
  logic middle_en;

  // Latency
  localparam ADDER_LATENCY = (CHANNEL_ADD_VLD == 1) ? ($clog2(
      KERNEL_AREA * KERNEL_NUM
  ) + 1) : ($clog2(
      KERNEL_AREA
  ) + 1);
  logic [ADDER_LATENCY-1:0] add_out_en;

  genvar h;
  generate
    for (h = 0; h < KERNEL_SIZE; h = h + 1) begin
      assign BUF_WIDTH_MAT[h] = h * BUF_WIDTH;
    end
  endgenerate

  // TODO: MAYBE Optimize Adder Tree for this task
  genvar n, ka, kn;  // NUM_PER_CYCLE, KERNEL_AREA, KERNEL_NUM
  generate
    if (CHANNEL_ADD_VLD) begin
      localparam INPUT_NUM = KERNEL_AREA * KERNEL_NUM;

      logic signed [INPUT_NUM*MULTIPLIED_WIDTH-1:0] adder_tree_input[NUM_PER_CYCLE-1:0];
      logic signed [OUT_WIDTH-1:0] adder_tree_output[NUM_PER_CYCLE-1:0];

      for (n = 0; n < NUM_PER_CYCLE; n = n + 1) begin
        for (kn = 0; kn < KERNEL_NUM; kn = kn + 1) begin
          for (ka = 0; ka < KERNEL_AREA; ka = ka + 1) begin
            assign adder_tree_input[n][(kn*KERNEL_AREA + (ka+1))*MULTIPLIED_WIDTH-1-:MULTIPLIED_WIDTH] = conv_mat[n][kn][ka];
          end
        end

        adder_tree #(
            .INPUT_NUM(INPUT_NUM),
            .IN_WIDTH (MULTIPLIED_WIDTH)
        ) adder_tree_inst (
            .clk(clk),
            .rst_n(rst_n),
            .add_en(add_en),
            .din(adder_tree_input[n]),
            .dout(adder_tree_output[n])
        );
        assign data_out[0][n] = adder_tree_output[n];
      end
    end else begin
      localparam INPUT_NUM = KERNEL_AREA;

      logic signed [INPUT_NUM*MULTIPLIED_WIDTH-1:0] adder_tree_input[NUM_PER_CYCLE*KERNEL_NUM-1:0];
      logic signed [OUT_WIDTH-1:0] adder_tree_output[KERNEL_NUM-1:0][NUM_PER_CYCLE-1:0];

      for (n = 0; n < NUM_PER_CYCLE; n = n + 1) begin
        for (kn = 0; kn < KERNEL_NUM; kn = kn + 1) begin
          for (ka = 0; ka < KERNEL_AREA; ka = ka + 1) begin
            assign adder_tree_input[n*(kn+1)][(ka+1)*MULTIPLIED_WIDTH-1-:MULTIPLIED_WIDTH] = conv_mat[n][kn][ka];
          end
          adder_tree #(
              .INPUT_NUM(INPUT_NUM),
              .IN_WIDTH (MULTIPLIED_WIDTH)
          ) adder_tree_inst (
              .clk(clk),
              .rst_n(rst_n),
              .add_en(add_en),
              .din(adder_tree_input[n*(kn+1)]),
              .dout(adder_tree_output[kn][n])
          );
          assign data_out[kn][n] = adder_tree_output[kn][n];
        end
      end
    end
  endgenerate

  always @(posedge clk or negedge rst_n) begin
    // TODO:Reset 和 IDLE 还需要斟酌
    if (~rst_n) begin
      w_idx <= 0;
      h_idx <= 0;
      buf_flag <= 0;
      buf_idx <= PAD_SIZE + BUF_WIDTH_MAT[PAD_SIZE];

      add_en <= 1'b0;
      read_en <= 1'b1;
      middle_en <= 1'b0;
      add_out_en <= '0;

      for (int i = 0; i < PAD_AREA; i = i + 1) begin
        buffer[i] <= '0;
      end

      for (int h = PAD_SIZE; h < KERNEL_SIZE; h = h + 1) begin
        for (int w = 0; w < PAD_SIZE; w = w + 1) begin
          buffer[h*BUF_WIDTH+w] <= '0;
          buffer[(h+1)*BUF_WIDTH-w-1] <= '0;
        end
      end

    end else if (clk_en) begin
      add_out_en <= {add_out_en[ADDER_LATENCY-2:0], add_en};
      case (c_state)
        IDLE: begin
          w_idx <= 0;
          h_idx <= 0;
          buf_flag <= 0;
          buf_idx <= PAD_SIZE + BUF_WIDTH_MAT[PAD_SIZE];

          add_en <= 1'b0;
          read_en <= 1'b1;
          middle_en <= 1'b0;
          add_out_en <= '0;

          for (int i = 0; i < PAD_AREA; i = i + 1) begin
            buffer[i] <= '0;
          end

          for (int h = PAD_SIZE; h < KERNEL_SIZE; h = h + 1) begin
            for (int w = 0; w < PAD_SIZE; w = w + 1) begin
              buffer[h*BUF_WIDTH+w] <= '0;
              buffer[(h+1)*BUF_WIDTH-w-1] <= '0;
            end
          end
        end

        READ: begin
          if (read_en) begin
            if (buf_idx >= BUF_SIZE - PAD_SIZE - 1) begin  // Done Reading, to FIRST_CONV
              buf_idx <= PAD_SIZE;
              read_en <= 1'b0;
            end else begin
              // Fill in the data
              for (int i = 0; i < NUM_PER_CYCLE; i = i + 1) begin
                buffer[buf_idx+i] <= data_in[(i+1)*IN_WIDTH-1-:IN_WIDTH];
              end

              next_buf_idx = buf_idx + NUM_PER_CYCLE;
              for (int h = 0; h < KERNEL_SIZE; h = h + 1) begin
                if (BUF_WIDTH_MAT[h] - PAD_SIZE == buf_idx) begin
                  next_buf_idx = buf_idx + 2 * PAD_SIZE;
                end
              end
              buf_idx <= next_buf_idx;
            end
          end
        end

        SIDE_CONV: begin
          w_idx <= w_idx + NUM_PER_CYCLE;  // 换列
          middle_en <= 1'b1;

          for (int n = w_idx; n < w_idx + NUM_PER_CYCLE; n = n + 1) begin
            for (int c = 0; c < KERNEL_NUM; c = c + 1) begin
              for (int h = 0; h < KERNEL_SIZE; h = h + 1) begin
                for (int w = 0; w < KERNEL_SIZE; w = w + 1) begin
                  if (h + buf_flag >= KERNEL_SIZE) begin
                    conv_mat[n-w_idx][c][h*KERNEL_SIZE+w] <= buffer[BUF_WIDTH_MAT[h]+n+w] * kernel[c][h+buf_flag-KERNEL_SIZE][w];
                  end else begin
                    conv_mat[n-w_idx][c][h*KERNEL_SIZE+w] <= buffer[BUF_WIDTH_MAT[h]+n+w] * kernel[c][h+buf_flag][w];
                  end
                end
              end
            end
          end

        end

        MIDDLE_CONV: begin
          add_en <= 1'b1;

          if (h_idx < ROI_SIZE - KERNEL_SIZE + 1) begin
            for (int i = 0; i < NUM_PER_CYCLE; i = i + 1) begin
              if (w_idx + i < ROI_SIZE) begin  // Boundary check for writing
                buffer[BUF_WIDTH_MAT[buf_flag] + w_idx + PAD_SIZE + i] <= data_in[(i + 1) * IN_WIDTH - 1 -: IN_WIDTH];
              end
            end
          end else begin  // Pad with zeros at the bottom of the image
            for (int i = 0; i < NUM_PER_CYCLE; i = i + 1) begin
              if (w_idx + i < ROI_SIZE) begin
                buffer[BUF_WIDTH_MAT[buf_flag]+w_idx+PAD_SIZE+i] <= '0;
              end
            end
          end

          if (buf_idx == BUF_SIZE - 1 - PAD_SIZE) begin
            buf_idx   <= PAD_SIZE;
            middle_en <= 1'b0;
          end else begin
            // Buffer Index Updates - THIS LOGIC IS FLAWED FOR MIDDLE_CONV AND IS NOW SUPERSEDED BY THE LOGIC ABOVE
            // The buf_idx is kept running to satisfy the end-of-row condition, but is not used for writing
            next_buf_idx = buf_idx + NUM_PER_CYCLE;
            for (int h = 0; h < KERNEL_SIZE; h = h + 1) begin
              if (BUF_WIDTH_MAT[h] - PAD_SIZE == buf_idx) begin
                next_buf_idx = buf_idx + 2 * PAD_SIZE;
              end
            end
            buf_idx <= next_buf_idx;
          end

          // H,W,Flag Index Updates
          if (w_idx == ROI_SIZE - 1) begin  // 卷积核到最右边换行
            middle_en <= 1'b0;  // 进入SIDE_CONV
            buf_flag  <= buf_flag + 1'b1;  // buf_flag换行
            if (buf_flag == KERNEL_SIZE) begin
              buf_flag <= 0;
            end
            w_idx <= 0;  // w换行

            // h换行
            next_h_idx = h_idx + 1'b1;
            if (next_h_idx == ROI_SIZE) begin  // 一张图已经搞定
              h_idx  <= 0;
              add_en <= 0;
            end else begin
              h_idx <= next_h_idx;
            end
          end else begin
            w_idx <= w_idx + NUM_PER_CYCLE;  // 换列
          end

          // Conv
          for (int n = w_idx; n < w_idx + NUM_PER_CYCLE; n = n + 1) begin
            for (int c = 0; c < KERNEL_NUM; c = c + 1) begin
              for (int h = 0; h < KERNEL_SIZE; h = h + 1) begin
                for (int w = 0; w < KERNEL_SIZE; w = w + 1) begin
                  if (h + buf_flag >= KERNEL_SIZE) begin
                    conv_mat[n-w_idx][c][h*KERNEL_SIZE+w] <= buffer[BUF_WIDTH_MAT[h]+n+w] * kernel[c][h+buf_flag-KERNEL_SIZE][w];
                  end else begin
                    conv_mat[n-w_idx][c][h*KERNEL_SIZE+w] <= buffer[BUF_WIDTH_MAT[h]+n+w] * kernel[c][h+buf_flag][w];
                  end
                end
              end
            end
          end

        end
      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      c_state <= IDLE;
    end else if (clk_en) begin
      c_state <= n_state;
    end
  end

  always @(*) begin
    case (c_state)
      IDLE: begin
        n_state = (conv_en && !add_en && read_en) ? READ : IDLE;
      end
      READ: begin
        n_state = conv_en ? (!read_en ? SIDE_CONV : READ) : IDLE;
      end
      SIDE_CONV: begin
        n_state = conv_en ? MIDDLE_CONV : IDLE;
      end
      MIDDLE_CONV: begin
        n_state = conv_en ? (middle_en ? MIDDLE_CONV : SIDE_CONV) : IDLE;
      end
      default: n_state = IDLE;
    endcase
    assign data_out_vld = add_out_en[ADDER_LATENCY-1];
  end
endmodule
