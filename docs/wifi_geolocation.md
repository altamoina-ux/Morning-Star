# ESP32 Wi-Fi 粗略定位

帽端固件周期扫描附近 Wi-Fi 接入点，将最多 20 个 BSSID（热点 MAC 地址）和 RSSI 信号强度经现有 `/ws/camera` WebSocket 上传。首次扫描约在设备联网 30 秒后开始，之后约每 2 分钟扫描一次。扫描期间暂停发送新的相机帧，避免扫描和图像上传同时占用链路。

后端将热点列表发送给 BeaconDB（`https://beacondb.net/v1/geolocate`）换取经纬度与服务估算的误差半径。请求关闭公网 IP 回退，因此不会把 IP 粗定位误报成 Wi-Fi 定位。SSID、Wi-Fi 密码和相机图像不会发送给定位服务。BSSID 和 RSSI 属于网络环境信息，使用该功能即表示允许它们发送给 BeaconDB。

## 使用

1. 在固件同目录的 `config.local.h` 中配置 ESP32 当前 Wi-Fi 和后端电脑局域网 IP。
2. 后端在 `yolo-blind` 环境运行，并允许电脑访问公网 BeaconDB 服务。
3. 编译并烧录 `firmware/esp32s3_gray_camera/esp32s3_gray_camera.ino`，让 ESP32 与后端连入可互通的网络。
4. 登录管理平台，在“实时环境监测”选择 ESP32 帽端并启动监测。页面显示估算坐标、误差半径、参与估算的热点数及更新时间。

无需新增 GPS 模块或 API 密钥。若周围有效热点少于两个、BeaconDB 没有该区域的热点记录或公网请求失败，页面会显示不可用原因，不会生成虚假坐标。定位仅适合粗略区域判断，不能用于导航、安全距离判断或紧急定位。电脑更换网络后，记得更新固件的 `BACKEND_HOST`。

## 服务地址

默认地址为 `https://beacondb.net/v1/geolocate`。可通过后端环境变量 `WIFI_GEOLOCATION_URL` 覆盖。页面通过需要登录的 `GET /api/tablet/location?device_id=esp32s3_cam_001` 获取最新状态。
