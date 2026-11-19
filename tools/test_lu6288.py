"""Send one SYN6288-compatible test phrase directly through a USB-to-TTL adapter."""
import argparse
import sys
import time
from pathlib import Path

import serial

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.tts_protocol import speech_command


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", required=True, help="USB-to-TTL COM port, for example COM5")
    parser.add_argument("--text", default="语音模块测试")
    args = parser.parse_args()
    frame = speech_command(args.text)[1:]
    with serial.Serial(args.port, 9600, timeout=1, write_timeout=2) as port:
        time.sleep(0.1)
        written = port.write(frame)
        port.flush()
    if written != len(frame):
        raise RuntimeError(f"sent {written} of {len(frame)} bytes")
    print(f"Sent one {len(frame)}-byte, 9600-baud LU6288 test frame on {args.port}.")


if __name__ == "__main__":
    main()
