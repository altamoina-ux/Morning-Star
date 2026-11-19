from backend.camera_stream import CameraFrames


JPEG = b'\xff\xd8preview\xff\xd9'


def test_web_camera_controller_is_served_without_caching():
    from fastapi.testclient import TestClient
    from backend.main import app

    client = TestClient(app)
    try:
        response = client.get('/camera-monitor.js')
        assert response.status_code == 200
        assert 'no-store' in response.headers['cache-control']
        assert 'class Monitor' in response.text
    finally:
        client.close()


def test_preview_cache_is_bounded_and_expires():
    now = [0.0]
    cache = CameraFrames(max_sources=2, max_age=3, clock=lambda: now[0])
    cache.publish('first', 1, JPEG)
    cache.publish('second', 2, JPEG)
    cache.publish('third', 3, JPEG)
    assert cache.get('first') is None
    assert cache.get('second').image == JPEG
    assert cache.get('third').seq == 3
    now[0] = 3.0
    assert cache.get('second') is None
    assert cache.get('third') is None


def test_invalid_frames_are_not_cached_and_disconnect_removes_preview():
    cache = CameraFrames()
    cache.publish('invalid/source', 1, JPEG)
    cache.publish('bad', 1, b'not-a-jpeg')
    cache.publish('oversize', 1, b'\xff\xd8' + b'x' * 2_000_000)
    assert cache.get('invalid/source') is None
    assert cache.get('bad') is None
    assert cache.get('oversize') is None
    cache.publish('device', 4, JPEG)
    assert cache.get('device') is not None
    cache.remove('device')
    assert cache.get('device') is None
