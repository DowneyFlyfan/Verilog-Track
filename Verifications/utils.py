import numpy as np
import math


def to_hex(val, width):
    """Converts a signed integer to a two's complement hex string."""
    if val >= (1 << (width - 1)) or val < -(1 << (width - 1)):
        val = max(-(1 << (width - 1)), min(val, (1 << (width - 1)) - 1))
    hex_chars = math.ceil(width / 4)

    return format(val & (2**width - 1), f"0{hex_chars}x")


def write_to_file(data, filename, width):
    """Writes numpy data to a file in hex format."""
    with open(filename, "w") as f:
        for val in data.flatten():
            f.write(f"{to_hex(int(val), width)}\n")


def read_hex_file(filename, width):
    """Reads a hex file and converts to signed integers."""
    with open(filename, "r") as f:
        hex_values = [line.strip() for line in f.readlines()]

    int_values = []
    for hex_val in hex_values:
        val = int(hex_val, 16)
        if (val >> (width - 1)) & 1:  # Check sign bit
            val -= 1 << width  # Convert to negative
        int_values.append(val)
    return np.array(int_values)
