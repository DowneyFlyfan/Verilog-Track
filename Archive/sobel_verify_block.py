import torch
import torch.nn.functional as F
import numpy as np
import os
from utils import *

# Parameters from Verilog
IN_DATA_WIDTH = 8
KERNEL_DATA_WIDTH = 4
MULTIPLIED_DATA_WIDTH = IN_DATA_WIDTH + KERNEL_DATA_WIDTH
OUT_DATA_WIDTH = MULTIPLIED_DATA_WIDTH + 5  # $log2(18) = 5


def main():
    sobel_x = torch.tensor([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=torch.float32)
    sobel_y = torch.tensor([[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=torch.float32)
    image = torch.arange(0, 64, dtype=torch.float32).view(8, 8)

    # Write data to files for the testbench
    write_to_file(image.numpy(), "texts\\input_fm.txt", IN_DATA_WIDTH)
    write_to_file(sobel_x.numpy(), "texts\\kernel_x.txt", KERNEL_DATA_WIDTH)
    write_to_file(sobel_y.numpy(), "texts\\kernel_y.txt", KERNEL_DATA_WIDTH)
    print("Input files (input_fm.txt, kernel_x.txt, kernel_y.txt) generated.")

    # Perform convolution in PyTorch for verification
    image_tensor = image.view(1, 1, 8, 8)
    conv_x = F.conv2d(image_tensor, sobel_x.view(1, 1, 3, 3), padding=1)
    conv_y = F.conv2d(image_tensor, sobel_y.view(1, 1, 3, 3), padding=1)
    expected_output = conv_x + conv_y
    expected_output_np = expected_output.numpy().squeeze()

    print("\nExpected output (PyTorch):")
    print(expected_output_np)

    # Check the result
    if not os.path.exists("texts\\output_fm.txt"):
        print("\n'output_fm.txt' not found.")

    try:
        verilog_output = read_hex_file("texts\\output_fm.txt", OUT_DATA_WIDTH)
        verilog_output = verilog_output.reshape(expected_output_np.shape)

        print("\nVerilog output (read from file):")
        print(verilog_output)

        # Compare results
        if np.array_equal(expected_output_np, verilog_output):
            print("\n✅ Verification successful! The outputs match exactly.")
        else:
            print("\n❌ Verification failed! The outputs do not match.")
            difference = expected_output_np - verilog_output
            print("\nDifference (Expected - Verilog):")
            print(difference)

    except Exception as e:
        print(f"\nAn error occurred while processing the output file: {e}")


if __name__ == "__main__":
    main()
