import asyncio
import json
from backend.config import settings
from backend.services import runtime

def test_direction_boundaries():
    assert runtime.direction(10,100) == "left"
    assert runtime.direction(50,100) == "front"
    assert runtime.direction(90,100) == "right"


def test_device_disconnect_cleans_up_session(tmp_path, monkeypatch):
    from backend.database import init_db
    from backend.main import device_ws

    monkeypatch.setattr(settings, "database_path", str(tmp_path / "device.sqlite3"))
    init_db()
    monkeypatch.setattr(runtime, "devices", {})
    events = []

    async def record_event(event):
        events.append(event)

    monkeypatch.setattr(runtime, "broadcast", record_event)

    class DeviceSocket:
        def __init__(self):
            self.messages = iter([
                {"type": "websocket.receive", "text": json.dumps({"type": "device_online", "device_id": "disconnect_check"})},
                {"type": "websocket.disconnect", "code": 1000},
            ])

        async def accept(self):
            pass

        async def receive(self):
            return next(self.messages)

    asyncio.run(device_ws(DeviceSocket()))
    assert "disconnect_check" not in runtime.devices
    assert [event["online"] for event in events] == [True, False]
