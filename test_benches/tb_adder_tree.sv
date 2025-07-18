`timescale 1ns / 1ps

module tb_adder_tree;
  localparam KERNEL_SIZE = 3;
  localparam IN_WIDTH = 8;
  localparam INPUT_NUM = 18;
  localparam LATENCY = $clog2(INPUT_NUM) + 1;
  localparam OUTPUT_DATA_WIDTH = IN_WIDTH + $clog2(INPUT_NUM);

  logic clk;
  logic rst_n;
  logic add_en = 1'b1;

  logic signed [INPUT_NUM*IN_WIDTH-1 : 0] din;
  logic signed [OUTPUT_DATA_WIDTH-1 : 0] dout;
  logic signed [IN_WIDTH-1:0] din_unpacked[INPUT_NUM-1:0];
  longint sum;

  adder_tree #(
      .INPUT_NUM(INPUT_NUM),
      .IN_WIDTH (IN_WIDTH)
  ) dut (
      .clk(clk),
      .rst_n(rst_n),
      .add_en(add_en),
      .din(din),
      .dout(dout)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    // 1. Reset the DUT
    rst_n = 1'b0;
    din   = '0;
    repeat (1) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // 2. Generate random inputs
    for (int i = 0; i < 5; i++) begin
      sum = 0;
      for (int j = 0; j < INPUT_NUM; j++) begin
        din_unpacked[j] = $random;
        din[(j+1)*IN_WIDTH-1-:IN_WIDTH] = din_unpacked[j];
        sum = sum + din_unpacked[j];
      end

      repeat (LATENCY) @(posedge clk);

      // 3. Check the output
      $display("Test Case %0d:", i + 1);
      $display("Inputs applied. Waiting %0d cycles for pipeline latency.", LATENCY);
      $display("DUT output: %d", dout);
      $display("Golden sum: %d", sum);

      if (dout == sum) begin
        $display("SUCCESS: DUT output matches golden sum.\n");
      end else begin
        $error("FAILURE: DUT output does NOT match golden sum.\n");
      end
    end

    // 4. Finish simulation
    $finish;
  end

endmodule
