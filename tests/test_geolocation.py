import asyncio

import httpx
import pytest

from backend import geolocation
from backend.geolocation import GeolocationError, locate_wifi

ACCESS_POINTS = [
    {"macAddress": "aa:bb:cc:dd:ee:ff", "signalStrength": -48},
    {"macAddress": "00:11:22:33:44:55", "signalStrength": -72},
]


def mock_client(monkeypatch, handler):
    original = httpx.AsyncClient
    monkeypatch.setattr(geolocation.httpx, "AsyncClient", lambda **kwargs: original(
        transport=httpx.MockTransport(handler), **kwargs))


def test_wifi_geolocation_sends_bssids_without_ip_fallback(monkeypatch):
    def handler(request):
        payload = __import__("json").loads(request.content)
        assert payload["considerIp"] is False
        assert payload["fallbacks"]["ipf"] is False
        assert [item["macAddress"] for item in payload["wifiAccessPoints"]] == [
            "AA:BB:CC:DD:EE:FF", "00:11:22:33:44:55"]
        assert all("SSID" not in item and "ssid" not in item for item in payload["wifiAccessPoints"])
        return httpx.Response(200, json={"location": {"lat": 31.2, "lng": 121.5}, "accuracy": 84})

    mock_client(monkeypatch, handler)
    result = asyncio.run(locate_wifi(ACCESS_POINTS))
    assert result["available"] is True
    assert result["latitude"] == 31.2
    assert result["accuracy_m"] == 84


def test_wifi_geolocation_requires_two_valid_unique_access_points():
    with pytest.raises(GeolocationError, match="两个有效") as error:
        asyncio.run(locate_wifi([ACCESS_POINTS[0], ACCESS_POINTS[0], {"macAddress": "bad", "signalStrength": -20}]))
    assert error.value.status == "insufficient_access_points"


@pytest.mark.parametrize(("response", "status"), [
    (httpx.Response(404), "no_match"),
    (httpx.Response(200, json={"location": {"lat": 999, "lng": 1}, "accuracy": 10}), "invalid_response"),
    (httpx.Response(200, json=[]), "invalid_response"),
])
def test_wifi_geolocation_reports_missing_or_invalid_results(monkeypatch, response, status):
    mock_client(monkeypatch, lambda request: response)
    with pytest.raises(GeolocationError) as error:
        asyncio.run(locate_wifi(ACCESS_POINTS))
    assert error.value.status == status


def test_wifi_geolocation_timeout_is_reported(monkeypatch):
    def handler(request):
        raise httpx.ReadTimeout("slow service", request=request)

    mock_client(monkeypatch, handler)
    with pytest.raises(GeolocationError) as error:
        asyncio.run(locate_wifi(ACCESS_POINTS))
    assert error.value.status == "provider_timeout"
