import torch
import torch.nn.functional as F
import numpy as np
import os
import math
import argparse  # Import argparse
from utils import *


class Tb_machine:
    def __init__(self):
        self.roi_size = 480
        self.in_width = 8
        self.kernel_size = 3
        self.kernel_data_width = 4
        self.adder_tree_input_num = 18
        self.pad_size = (self.kernel_size - 1) // 2
        self.path = "..\\texts\\"
        self.img_shape = (1, 1, self.roi_size, self.roi_size)
        self.out_width = (
            self.in_width
            + self.kernel_data_width
            + math.ceil(math.log2(self.adder_tree_input_num))
        )

    def data_gen(self):
        self.sobel_x = torch.tensor(
            [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], dtype=torch.int16
        )
        self.sobel_y = torch.tensor(
            [[-1, -2, -1], [0, 0, 0], [1, 2, 1]], dtype=torch.int16
        )
        self.image = torch.randint(
            low=0,
            high=255,
            size=(1, 1, self.roi_size, self.roi_size),
            dtype=torch.int16,
        )

        # Conv
        conv_x = F.conv2d(
            self.image,
            self.sobel_x.view(1, 1, self.kernel_size, self.kernel_size),
            padding=self.pad_size,
        )
        conv_y = F.conv2d(
            self.image,
            self.sobel_y.view(1, 1, self.kernel_size, self.kernel_size),
            padding=self.pad_size,
        )
        self.expected_output = conv_x + conv_y

    def write(self):
        write_to_file(self.image.numpy(), self.path + "input_img.txt", self.in_width)
        write_to_file(
            torch.cat([self.sobel_x, self.sobel_y], dim=0).numpy(),
            self.path + "kernel.txt",
            self.kernel_data_width,
        )
        write_to_file(
            self.expected_output.numpy(),
            self.path + "expected_output.txt",
            self.out_width,
        )
        print("input_img.txt, kernel.txt, and expected_output generated.")

    def verification(self):
        # Check the result
        if not os.path.exists(self.path + "expected_output.txt"):
            print("\n'expected_output.txt' not found.")
            return
        if not os.path.exists(self.path + "output_img.txt"):
            print("\n'output_img.txt' not found.")
            return

        try:
            expected_output = read_hex_file(
                self.path + "expected_output.txt", self.out_width
            )
            expected_output = expected_output.reshape(self.img_shape)
            verilog_output = read_hex_file(self.path + "output_img.txt", self.out_width)
            verilog_output = verilog_output.reshape(self.img_shape)

            print("\nExpected output:")
            print(expected_output)
            print("\nVerilog output:")
            print(verilog_output)

            # Compare results
            if np.array_equal(expected_output, verilog_output):
                print("\n✅ Verification successful! The outputs match exactly.")
            else:
                print("\n❌ Verification failed! The outputs do not match.")
                difference = expected_output - verilog_output
                print("\nDifference (Expected - Verilog):")
                print(difference)

        except Exception as e:
            print(f"\nAn error occurred while processing the output file: {e}")

    def forward(self, way):
        if way == 1:
            self.data_gen()
            self.write()
        elif way == 2:
            self.verification()
        else:
            raise ValueError("Wrong Value of parameter 'way' ! It should be 1 or 2!!!")


if __name__ == "__main__":
    machine = Tb_machine()
    machine.forward(2)
