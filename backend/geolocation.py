"""Wi-Fi access-point geolocation through the BeaconDB API."""
import math
import re

import httpx

from .config import settings
from .database import now_iso

_MAC = re.compile(r"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$")


class GeolocationError(Exception):
    def __init__(self, status, detail):
        super().__init__(detail)
        self.status = status


async def locate_wifi(access_points):
    cleaned = []
    seen = set()
    for access_point in access_points[:20]:
        if not isinstance(access_point, dict):
            continue
        mac = str(access_point.get("macAddress", "")).upper()
        signal = access_point.get("signalStrength")
        if (not _MAC.fullmatch(mac) or mac in seen or isinstance(signal, bool)
                or not isinstance(signal, int) or not -120 <= signal <= 0):
            continue
        seen.add(mac)
        cleaned.append({"macAddress": mac, "signalStrength": signal})
    if len(cleaned) < 2:
        raise GeolocationError("insufficient_access_points", "至少需要两个有效的 Wi-Fi 热点")

    payload = {
        "wifiAccessPoints": cleaned,
        "considerIp": False,
        "fallbacks": {"ipf": False},
    }
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            response = await client.post(settings.wifi_geolocation_url, json=payload)
        if response.status_code == 404:
            raise GeolocationError("no_match", "定位数据库未匹配到附近热点")
        response.raise_for_status()
        data = response.json()
    except GeolocationError:
        raise
    except httpx.TimeoutException as error:
        raise GeolocationError("provider_timeout", "BeaconDB 定位服务请求超时") from error
    except (httpx.HTTPError, ValueError) as error:
        raise GeolocationError("provider_unavailable", "BeaconDB 定位服务暂不可用") from error

    if not isinstance(data, dict):
        raise GeolocationError("invalid_response", "定位服务返回的数据格式无效")
    location = data.get("location") or {}
    if not isinstance(location, dict):
        raise GeolocationError("invalid_response", "定位服务返回的数据格式无效")
    try:
        latitude = float(location["lat"])
        longitude = float(location["lng"])
        accuracy = float(data["accuracy"])
    except (KeyError, TypeError, ValueError) as error:
        raise GeolocationError("invalid_response", "定位服务返回的数据格式无效") from error
    if (not math.isfinite(latitude) or not -90 <= latitude <= 90
            or not math.isfinite(longitude) or not -180 <= longitude <= 180
            or not math.isfinite(accuracy) or accuracy < 0):
        raise GeolocationError("invalid_response", "定位服务返回了无效坐标")
    return {
        "available": True,
        "status": "located",
        "latitude": latitude,
        "longitude": longitude,
        "accuracy_m": accuracy,
        "provider": "BeaconDB",
        "access_points_used": len(cleaned),
        "updated_at": now_iso(),
    }
