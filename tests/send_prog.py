#!/usr/bin/env python3
# Stream hex to bootloader
# python3 tests/send_prog.py <serial-port> <hexfile>

import sys
import serial


def load_words(path):
    words = []
    for line in open(path):
        line = line.strip()
        if not line or line.startswith("@"):
            continue
        words += [int(tok, 16) for tok in line.split()]
    return words


def main():
    port, hexfile = sys.argv[1], sys.argv[2]
    words = load_words(hexfile)
    if not 1 <= len(words) <= 16384:
        sys.exit(f"word count {len(words)} out of range 1..16384")
    ser = serial.Serial(port, 28800, timeout=1)
    ser.write(len(words).to_bytes(4, "little"))  # 4-byte count, LSB-first
    for w in words:
        ser.write(w.to_bytes(4, "little"))  # LSB-first
    ser.flush()
    ser.close()
    print(f"sent {len(words)} words to {port}")


if __name__ == "__main__":
    main()
