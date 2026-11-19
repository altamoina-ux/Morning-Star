"""Read-only camera timing: serial upload stats plus real backend detections."""
import argparse
import asyncio
import json
import re
import statistics
import threading
import time
from pathlib import Path

import serial
import websockets


def distribution(values):
    if not values:
        return None
    ordered = sorted(values)
    return dict(count=len(values), mean=round(statistics.mean(values), 2),
                median=statistics.median(values), p95=ordered[int((len(ordered) - 1) * .95)],
                max=max(values))


async def measure(args):
    records, detections, events, errors = [], [], [], []
    stop = threading.Event()
    port = serial.Serial(port=None, baudrate=115200, timeout=.25)
    port.dtr = port.rts = False
    port.port = args.port
    port.open()
    started = time.monotonic()

    def serial_reader():
        try:
            while not stop.is_set():
                line = port.readline().decode('utf-8', errors='replace').strip()
                if line:
                    records.append(dict(t=round(time.monotonic() - started, 4), line=line))
        except (OSError, serial.SerialException) as error:
            errors.append(str(error))

    reader = threading.Thread(target=serial_reader, daemon=True)
    reader.start()
    try:
        async with websockets.connect(args.socket, open_timeout=10) as socket:
            while (remaining := args.seconds - (time.monotonic() - started)) > 0:
                try:
                    message = json.loads(await asyncio.wait_for(socket.recv(), remaining))
                except asyncio.TimeoutError:
                    break
                if message.get('device_id') != 'esp32s3_cam_001':
                    continue
                stamp = round(time.monotonic() - started, 4)
                if message.get('type') == 'detection_update':
                    detections.append(dict(t=stamp, seq=message.get('image_seq'),
                                           status=message.get('model_status'),
                                           simulation=message.get('simulation', False)))
                elif message.get('type') == 'device_status':
                    events.append(dict(t=stamp, online=message.get('online')))
    finally:
        elapsed = time.monotonic() - started
        stop.set()
        reader.join(timeout=2)
        port.close()
    uploads, ack, capture, age = [], [], [], []
    for item in records:
        line = item['line']
        match = re.search(r'bytes=(\d+), encode_ms=(\d+), send=(\w+), write_ms=(\d+)', line)
        if match:
            uploads.append(dict(t=item['t'], bytes=int(match[1]), encode=int(match[2]),
                                sent=match[3], write=int(match[4])))
        match = re.search(r'Frame ACK, total=(\d+) ms, wait=(\d+) ms', line)
        if match:
            ack.append(int(match[2]))
        match = re.search(r'capture_ms=(\d+), age_ms=(\d+)', line)
        if match:
            capture.append(int(match[1]))
            age.append(int(match[2]))
    real = [item for item in detections if item['status'] == 'ready' and not item['simulation']]
    gaps = [(b['t'] - a['t']) * 1000 for a, b in zip(real, real[1:])]
    active_fps = ((len(uploads) - 1) / (uploads[-1]['t'] - uploads[0]['t'])
                  if len(uploads) > 1 else 0)
    summary = dict(elapsed=round(elapsed, 2), uploads=len(uploads),
                   active_upload_fps=round(active_fps, 2), real_detections=len(real),
                   detection_fps=round(len(real) / elapsed, 2),
                   bytes=distribution([x['bytes'] for x in uploads]),
                   encode_ms=distribution([x['encode'] for x in uploads]),
                   write_ms=distribution([x['write'] for x in uploads]),
                   ack_ms=distribution(ack), capture_ms=distribution(capture),
                   frame_age_ms=distribution(age), detection_gap_ms=distribution(gaps),
                   send_failures=sum(x['sent'] != 'ok' for x in uploads),
                   events=events, errors=errors,
                   serial_errors=[x for x in records if any(word in x['line'].lower()
                                  for word in ('failed', 'timeout', 'disconnected', 'overflow'))])
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(dict(summary=summary, serial=records,
                                     detections=detections), indent=2), encoding='utf-8')
    print(json.dumps(summary), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', default='COM3')
    parser.add_argument('--socket', default='ws://127.0.0.1:8765/ws/web')
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--output', required=True)
    options = parser.parse_args()
    if options.seconds <= 0:
        parser.error('--seconds must be positive')
    asyncio.run(measure(options))
