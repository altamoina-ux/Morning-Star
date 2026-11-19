# WebSocket 通信协议（第一版）

## 当前灰度硬件入口

已新增 `/ws/camera` 直接接收一消息一帧、固定 76,800 字节的 320×240 灰度像素。
默认兼容原始 L/R 固件；`?device_id=esp32s3_cam_001&protocol=2` 增加文本 ACK 和
二进制 B（双侧）/ S（停止）。完整格式、启动命令和引脚冲突见
[ESP32-S3 灰度摄像头联调](esp32s3_gray_camera.md)。它不使用下文的 QH 头。

下文描述旧 `/ws/device` 协议及部分规划内容。完整音频、设备鉴权、分片重组、
错误码和执行回执尚未全部实现，不能把规划当作当前能力。

## 端点

- 设备：`ws://<电脑局域网IP>:8765/ws/device`
- 网页：`ws://<电脑局域网IP>:8765/ws/web`

端口由启动命令指定，路径在路由中固定。连接后先发送 `device_online`，随后每 10 秒发送 `heartbeat`。旧端点目前未强制校验设备共享密钥，仅用于可信局域网联调。

## JSON 公共字段

`type`（必填）、`device_id`、`seq`（单调递增序列号）、`timestamp`（UTC ISO 8601）、`request_id`（需要应答的消息）。未知类型返回 `error`，不应导致连接关闭。

## 控制与状态消息

```json
{"type":"device_online","device_id":"qiming_hat_001","firmware_version":"0.1.0","capabilities":{"camera":true,"audio_in":true,"speaker":true},"timestamp":"2026-01-01T00:00:00Z"}
{"type":"heartbeat","device_id":"qiming_hat_001","battery_percent":null,"camera_ok":true,"mic_ok":true,"timestamp":"2026-01-01T00:00:00Z"}
{"type":"device_command","command":"vibrate","direction":"left","duration_ms":300,"request_id":"abc"}
{"type":"device_command","command":"speak","text":"左侧有行人","audio_format":"pcm_s16le","sample_rate":16000,"request_id":"abc"}
```

## 二进制帧头

二进制 WebSocket 帧必须使用以下小端固定头，后接 payload；不得把任意二进制当 JSON 字符串：

`magic[2] = QH`、`version[1]`、`frame_type[1]`（1=image/jpeg，2=audio/pcm 预留）、`header_len[2] = 26`、`seq[4]`、`timestamp_ms[8]`、`chunk_index[2]`、`chunk_total[2]`、`payload_len[4]`、`payload[variable]`。设备 ID 由先前的 JSON 上线消息关联，不在这个固定头中。

当前旧端点只实现部分头部解析和整帧图像接收，尚未完整校验长度、序列号、设备身份或实现分片重组。

## 预警与检测消息

```json
{"type":"detection_update","device_id":"qiming_hat_001","image_seq":42,"objects":[{"class":"person","confidence":0.95,"bbox":[12,44,260,420],"direction":"left"}],"model_status":"ready","timestamp":"2026-01-01T00:00:00Z"}
{"type":"obstacle_alert","direction":"front","object":"person","confidence":0.95,"vibration":"both","voice_text":"前方有行人","cooldown_ms":2000,"timestamp":"2026-01-01T00:00:00Z"}
```

## 语音消息

设备上传音频帧后，服务端发送：

```json
{"type":"asr_result","text":"前面有什么","request_type":"environment_query","timestamp":"2026-01-01T00:00:00Z"}
{"type":"voice_reply","text":"前方检测到一名行人","audio_format":"pcm_s16le","sample_rate":16000,"channels":1,"audio_seq":7,"timestamp":"2026-01-01T00:00:00Z"}
```

随后以 `frame_type=2` 的二进制帧发送音频。预警音频优先级高于环境查询，高于普通对话。

## 错误码

`AUTH_FAILED` 身份校验失败；`BAD_FRAME` 二进制头/长度错误；`UNKNOWN_DEVICE` 未注册设备；`MODEL_UNAVAILABLE` YOLO/FunASR/TTS 未就绪；`STALE_DETECTION` 环境缓存已过期；`QUEUE_FULL` 服务端队列已满；`COMMAND_TIMEOUT` 设备未确认；`INVALID_CONFIG` 参数校验失败。
