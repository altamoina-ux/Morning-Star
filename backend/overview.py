"""Read-only dashboard statistics and lightweight model availability checks."""
import asyncio
import time
from datetime import datetime, time as day_time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import httpx

from .config import settings
from .database import db, now_iso
from .services import runtime

_probe_cache = {}
_probe_lock = asyncio.Lock()
_SIMULATED = "substr(lower(coalesce(device_id,'')),1,10)='simulator_'"


def dashboard_statistics(tz_name, now=None):
    try:
        zone = ZoneInfo(tz_name)
    except (ZoneInfoNotFoundError, ValueError):
        raise ValueError("无效的时区") from None
    today = (now or datetime.now(timezone.utc)).astimezone(zone).date()
    windows = []
    for offset in range(6, -1, -1):
        date = today - timedelta(days=offset)
        start = datetime.combine(date, day_time.min, tzinfo=zone)
        end = datetime.combine(date + timedelta(days=1), day_time.min, tzinfo=zone)
        windows.append((date.isoformat(), start.astimezone(timezone.utc).isoformat(), end.astimezone(timezone.utc).isoformat()))
    with db() as connection:
        rows = connection.execute(
            "WITH days(day,start_at,end_at) AS (VALUES " + ','.join('(?,?,?)' for _ in windows) + ") "
            "SELECT days.day, COUNT(o.id) AS total, "
            "coalesce(sum(CASE WHEN o.id IS NOT NULL AND substr(lower(coalesce(o.device_id,'')),1,10)='simulator_' THEN 1 ELSE 0 END),0) AS simulation "
            "FROM days LEFT JOIN obstacle_logs o ON julianday(o.detected_at)>=julianday(days.start_at) "
            "AND julianday(o.detected_at)<julianday(days.end_at) GROUP BY days.day ORDER BY days.day",
            tuple(value for row in windows for value in row),
        ).fetchall()
        trend = [{"date": row['day'], "real": row['total'] - row['simulation'], "simulation": row['simulation']} for row in rows]
        voices = connection.execute(
            "SELECT count(*) AS total, coalesce(sum(CASE WHEN " + _SIMULATED +
            " OR asr_status='simulation' OR tts_status='simulation' THEN 1 ELSE 0 END),0) AS simulation "
            "FROM voice_logs WHERE julianday(occurred_at)>=julianday(?) AND julianday(occurred_at)<julianday(?)",
            windows[-1][1:],
        ).fetchone()
        alerts = [dict(row) for row in connection.execute(
            "SELECT id,device_id,detected_at,object_class,direction,confidence,voice_text, CASE WHEN " + _SIMULATED +
            " THEN 'simulation' ELSE 'real' END AS source FROM obstacle_logs ORDER BY julianday(detected_at) DESC,id DESC LIMIT 5"
        ).fetchall()]
        interactions = [dict(row) for row in connection.execute(
            "SELECT id,device_id,occurred_at,user_text,reply_text,request_type, CASE WHEN " + _SIMULATED +
            " OR asr_status='simulation' OR tts_status='simulation' THEN 'simulation' ELSE 'real' END AS source "
            "FROM voice_logs ORDER BY julianday(occurred_at) DESC,id DESC LIMIT 5"
        ).fetchall()]
        real_devices_seen = connection.execute("SELECT count(*) FROM device_info WHERE NOT (" + _SIMULATED + ")").fetchone()[0]
    return {
        "timezone": tz_name, "date": today.isoformat(), "trend": trend,
        "today_alerts": {**trend[-1], "total": trend[-1]['real'] + trend[-1]['simulation']},
        "today_voices": {"total": voices['total'], "real": voices['total'] - voices['simulation'], "simulation": voices['simulation']},
        "recent_alerts": alerts, "recent_voices": interactions, "real_devices_seen": real_devices_seen,
    }


async def _probe_model():
    if not settings.openai_base_url or not settings.openai_model:
        return {"state": "unconfigured", "label": "未配置", "detail": "请配置对话 / 识字模型"}
    headers = {"Authorization": "Bearer " + settings.openai_api_key} if settings.openai_api_key else {}
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            response = await client.get(settings.openai_base_url.rstrip('/') + '/models', headers=headers)
            response.raise_for_status()
            models = {item['id'] for item in response.json()['data']}
        if settings.openai_model not in models:
            return {"state": "missing", "label": "未找到模型", "detail": settings.openai_model}
        return {"state": "available", "label": "模型已安装", "detail": settings.openai_model}
    except httpx.HTTPStatusError as error:
        return {"state": "error", "label": "连接异常", "detail": "接口拒绝访问" if error.response.status_code in (401, 403) else "无法读取模型列表"}
    except httpx.RequestError:
        return {"state": "offline", "label": "服务未连接", "detail": "请检查 Ollama 或配置的模型服务"}
    except (ValueError, TypeError, KeyError):
        return {"state": "error", "label": "状态未知", "detail": "模型服务未返回有效的模型列表"}


async def model_status():
    key = (settings.openai_base_url, settings.openai_model, settings.openai_api_key)
    async with _probe_lock:
        if _probe_cache.get('key') == key and time.monotonic() - _probe_cache.get('at', 0) < 20:
            return _probe_cache['value']
        value = await _probe_model()
        _probe_cache.update(key=key, at=time.monotonic(), value=value)
        return value


async def overview(tz_name):
    stats, llm = await asyncio.gather(asyncio.to_thread(dashboard_statistics, tz_name), model_status())
    connected = list(runtime.devices)
    real_online = sum(not name.lower().startswith('simulator_') for name in connected)
    simulated_online = len(connected) - real_online
    yolo_ready = runtime.model is not None
    return {
        **stats, "generated_at": now_iso(), "mode": "simulation" if settings.simulation_mode else "live",
        "devices": {"real_online": real_online, "simulation_online": simulated_online, "seen": stats['real_devices_seen']},
        "yolo": {"state": "ready" if yolo_ready else "unavailable", "label": "已加载" if yolo_ready else "不可用",
                 "detail": "检测模型已加载" if yolo_ready else "请检查模型权重和后端启动日志"},
        "llm": llm,
    }
