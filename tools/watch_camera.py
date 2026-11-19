"""Observe the existing detection socket without uploading frames or commands."""
import argparse
import asyncio
import json
import sys
import time
from urllib.parse import urlsplit, urlunsplit

import websockets


async def watch(server, device_id, seconds):
    parts = urlsplit(server)
    if parts.scheme not in ("http", "https") or not parts.netloc:
        raise ValueError("--server must be an http:// or https:// server address")
    address = urlunsplit(("wss" if parts.scheme == "https" else "ws",
                          parts.netloc, "/ws/web", "", ""))
    count = ready = errors = 0
    disconnects = sequence_resets = 0
    previous_seq = None
    classes = set()
    started = time.monotonic()
    print(f"Watching {device_id} for {seconds:g}s via {address}", flush=True)
    async with websockets.connect(address, open_timeout=10) as socket:
        while True:
            remaining = seconds - (time.monotonic() - started)
            if remaining <= 0:
                break
            try:
                message = json.loads(await asyncio.wait_for(socket.recv(), remaining))
            except asyncio.TimeoutError:
                break
            if message.get("device_id") != device_id:
                continue
            if message.get("type") == "device_status":
                if not message.get("online"):
                    disconnects += 1
                print(json.dumps({"device_online": message.get("online")}), flush=True)
                continue
            if message.get("type") != "detection_update":
                continue
            count += 1
            seq = message.get("image_seq")
            if isinstance(seq, int):
                if previous_seq is not None and seq < previous_seq:
                    sequence_resets += 1
                previous_seq = seq
            status = message.get("model_status")
            is_real = status == "ready" and not message.get("simulation")
            ready += int(is_real)
            errors += int(status in ("error", "unavailable"))
            objects = message.get("objects", [])
            classes.update(str(obj.get("class", "unknown")) for obj in objects)
            summary = [{key: obj.get(key) for key in ("class", "direction", "confidence")}
                       for obj in objects]
            print(json.dumps({"seq": message.get("image_seq"), "model_status": status,
                              "real_inference": is_real,
                              "frame": [message.get("frame_width"), message.get("frame_height")],
                              "objects": summary, "error": message.get("error")},
                             ensure_ascii=False), flush=True)
    print(json.dumps({"summary": {"device_id": device_id, "detection_frames": count,
                                  "real_ready_frames": ready, "model_errors": errors,
                                  "disconnect_events": disconnects, "sequence_resets": sequence_resets,
                                  "classes": sorted(classes)}}, ensure_ascii=False), flush=True)
    if not count:
        print("No detection frames received. Check camera serial output, backend address and source ID.", flush=True)
    elif ready and not classes:
        print("Real inference completed with no detected objects; aim at a well-lit supported object.", flush=True)
    return 0 if ready and not errors else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", default="http://127.0.0.1:8765")
    parser.add_argument("--device", default="esp32s3_cam_001")
    parser.add_argument("--seconds", type=float, default=30)
    args = parser.parse_args()
    if args.seconds <= 0:
        parser.error("--seconds must be greater than zero")
    try:
        return asyncio.run(watch(args.server, args.device, args.seconds))
    except (ValueError, OSError, websockets.WebSocketException) as error:
        print(f"Camera observer failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
