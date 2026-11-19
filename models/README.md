# YOLOv8 模型

本项目使用 Ultralytics 官方 YOLOv8 权重，默认文件名为 `yolov8n.pt`。`n` 版本体积小、适合 Windows CPU 演示；有 NVIDIA GPU 时可以换成 `yolov8s.pt` 或更大模型。

## 下载

在后端虚拟环境中执行：

```powershell
cd QimingHat\backend
.\.venv\Scripts\Activate.ps1
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')"
```

然后确认文件位于：

```text
QimingHat/backend/models/yolov8n.pt
```

也可以设置：

```env
YOLO_WEIGHTS=C:/absolute/path/to/yolov8n.pt
```

模型下载和安装需要网络；下载完成后，YOLO 推理本身可以在局域网离线运行。系统不会在模型缺失或模型异常时生成虚假识别结果。
