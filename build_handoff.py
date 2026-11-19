from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from pathlib import Path

OUT = Path(r'C:\Users\67028\Desktop\启明帽项目开发交接文档.docx')

def shade(cell, fill):
    shd = OxmlElement('w:shd'); shd.set(qn('w:fill'), fill); cell._tc.get_or_add_tcPr().append(shd)
def cell_text(cell, value, bold=False, color=None):
    cell.text = ''; p = cell.paragraphs[0]; r = p.add_run(str(value)); r.bold = bold
    if color: r.font.color.rgb = RGBColor.from_string(color)
def make_table(doc, headers, rows):
    t = doc.add_table(rows=1, cols=len(headers)); t.style = 'Table Grid'; t.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i,h in enumerate(headers): cell_text(t.rows[0].cells[i], h, True, 'FFFFFF'); shade(t.rows[0].cells[i], '2E74B5')
    for row in rows:
        cells = t.add_row().cells
        for i,v in enumerate(row): cell_text(cells[i], v)
    return t
def bullet(doc, text): doc.add_paragraph(text, style='List Bullet')
def numbered(doc, text): doc.add_paragraph(text, style='List Number')

doc = Document(); sec = doc.sections[0]
sec.top_margin = Inches(.75); sec.bottom_margin = Inches(.75); sec.left_margin = Inches(.85); sec.right_margin = Inches(.85)
normal = doc.styles['Normal']; normal.font.name='Calibri'; normal.font.size=Pt(10.5); normal.paragraph_format.space_after=Pt(6); normal.paragraph_format.line_spacing=1.15
for name,size,color,before,after in [('Heading 1',16,'2E74B5',16,8),('Heading 2',13,'2E74B5',12,6),('Heading 3',11,'1F4D78',8,4)]:
    s=doc.styles[name]; s.font.name='Calibri'; s.font.size=Pt(size); s.font.bold=True; s.font.color.rgb=RGBColor.from_string(color); s.paragraph_format.space_before=Pt(before); s.paragraph_format.space_after=Pt(after)

p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('启明帽（QimingHat）'); r.bold=True; r.font.size=Pt(25); r.font.color.rgb=RGBColor(31,77,120)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('项目开发进度与后续开发交接文档'); r.font.size=Pt(17); r.font.color.rgb=RGBColor(46,116,181)
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('面向：后续接手开发人员  |  文档日期：2026-11-16'); r.italic=True
p=doc.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER; r=p.add_run('当前版本：软件模拟联调版 / YOLOv8 官方权重已准备'); r.bold=True; r.font.color.rgb=RGBColor(0,128,96)

doc.add_heading('1. 项目概况',1)
doc.add_paragraph('启明帽是一套帽载式视障环境感知预警系统，采用 ESP32-S3 CAM 采集图像和音频，Windows 电脑端运行 YOLO、FunASR、TTS 和可配置大模型，浏览器提供陪护管理界面。系统目标是通过左右震动与语音播报，为佩戴者提供环境辅助信息。')
doc.add_paragraph('核心边界：ESP32 只负责采集、传输和执行硬件指令；所有 AI 推理在电脑后端完成。普通目标检测不能替代盲杖、导盲犬，也不能宣传为绝对可靠的避障能力。')

doc.add_heading('2. 当前完成情况',1)
make_table(doc,['模块','状态','说明'],[
('工程目录','已完成','backend、frontend、firmware、docs、models、tools、tests 已建立'),
('Python 后端','基础版已完成','FastAPI、SQLite、WebSocket、设备状态、检测队列、预警记录、配置接口'),
('YOLOv8','权重已下载','官方 yolov8n.pt 已放置于 backend/models/，已验证可加载 80 类 COCO 标签'),
('Web 前端','基础产品版已完成','中文管理平台、导航、总览、监测、记录、设备、参数和联调页面'),
('无硬件模拟联调','已完成','tools/simulator.py 可模拟设备上线、心跳和 JPEG 图像帧'),
('ESP32 固件','框架版','摄像头、WebSocket、马达、ADC 音频接口已写入，但未经过实机编译和板卡验证'),
('FunASR/TTS/LU6288','未完成','接口边界尚未接通真实识别、合成和串口播报'),
('真实硬件联调','未开始','等待嘉顺电子 ESP32-S3 CAM 和外设到货')])

doc.add_heading('3. 现有目录与关键文件',1)
make_table(doc,['路径','用途'],[
('backend/main.py','FastAPI、WebSocket、健康检查、设备/日志/配置/导出接口'),
('backend/services.py','YOLO 检测任务、方位判断、预警冷却、环境查询、对话服务'),
('backend/config.py','环境变量和路径配置'),
('backend/database.py','SQLite 初始化、连接和系统日志'),
('backend/models/yolov8n.pt','Ultralytics 官方 YOLOv8 Nano 权重'),
('frontend/index.html','中文管理平台单页界面'),
('firmware/config.h','所有 ESP32 GPIO、Wi-Fi、后端地址宏定义'),
('firmware/firmware.ino','Arduino 主程序'),
('tools/simulator.py','无硬件软件联调模拟器'),
('docs/','架构、通信协议、硬件接线和安装说明')])

doc.add_heading('4. 当前软件运行方法',1)
doc.add_heading('4.1 虚拟环境和依赖',2)
doc.add_paragraph('当前机器使用 Python 3.10.9；系统没有 Python 3.11，因此虚拟环境使用 Python 3.10。')
numbered(doc, r'cd QimingHat\backend'); numbered(doc, r'.\.venv\Scripts\Activate.ps1'); numbered(doc, 'pip install -r requirements.txt')
doc.add_heading('4.2 启动后端',2); numbered(doc, r'python -m uvicorn backend.main:app --host 127.0.0.1 --port 8765')
doc.add_heading('4.3 无硬件模拟联调',2)
doc.add_paragraph('将 backend/.env 设置为 SIMULATION_MODE=true，然后另开终端运行：')
numbered(doc, r'cd QimingHat'); numbered(doc, r'backend\.venv\Scripts\python.exe tools\simulator.py')
doc.add_paragraph('浏览器打开 http://127.0.0.1:8765。模拟数据会标记为 simulation，不能作为真实硬件或真实识别验收。')
doc.add_heading('4.4 YOLOv8 权重',2)
doc.add_paragraph('已下载并验证 backend/models/yolov8n.pt。该权重是官方 YOLOv8 Nano COCO 预训练模型，可识别 80 类目标，适合 CPU 演示。YOLOv8n 不是自定义地面障碍物模型，也不能直接输出真实距离。')

doc.add_heading('5. 目前最重要的未完成工作',1)
for x in ['接入 FunASR：实现 PCM 音频接收、16 kHz/16 bit/单声道校验、模型加载、离线识别和异常状态广播。','接入本地中文 TTS：实现语音缓存、预警/环境查询/普通对话三级优先级，并输出适合 LU6288 的音频或串口指令。','确认 LU6288 的准确通信协议：补充波特率、帧头、编码、音量、播放完成反馈，禁止凭空定义模块指令。','完善真实图像展示：后端保存或推送检测后的 JPEG，前端使用图片或 Canvas 绘制边界框、区域线和目标列表。','补齐前端筛选、分页、清空测试数据、硬件调试按钮和命令回执。','补齐 WebSocket 认证：设备 Token、序列号校验、未知设备拒绝、命令超时和错误码。','实机验证固件：核对嘉顺电子板卡摄像头 GPIO、ADC、UART、I2C、PSRAM 和 USB/JTAG 资源后再烧录。','补齐测试：API、WebSocket、图像帧、音频帧、模型异常、并发和断线重连测试。']: bullet(doc,x)

doc.add_heading('6. 硬件接入前必须确认',1)
make_table(doc,['项目','必须确认的信息'],[
('摄像头','OV2640 的 PWDN、RESET、XCLK、SIOD、SIOC、D0-D7、VSYNC、HREF、PCLK 映射'),
('音频输入','MAX9814 OUT 实际连接的 ADC1 GPIO，采样电压范围和是否与摄像头冲突'),
('LU6288','UART 电平、波特率、发送协议、中文字库/编码和喇叭功放接法'),
('OLED','SDA/SCL GPIO、I2C 地址（常见 0x3C 但需实测）'),
('马达','高低电平触发逻辑、MOSFET/三极管驱动、续流二极管和独立供电'),
('供电','18650 保护、TP4056 保护版、AMS1117 发热、电池电压和电流裕量')])
doc.add_paragraph('当前 firmware/config.h 中的 GPIO 是通用候选映射，不能视为嘉顺电子具体批次的最终接线表。')

doc.add_heading('7. 建议后续开发顺序',1)
for x in ['先冻结后端协议和数据结构，增加严格认证与错误码。','接入 FunASR 和 TTS，先用电脑麦克风/扬声器完成纯软件闭环。','完成真实 YOLOv8 图片检测、标注图像推送和前端 Canvas。','完善 Web 管理端的记录筛选、导出和硬件调试交互。','拿到开发板后，单独验证摄像头、Wi-Fi/WebSocket、马达、MAX9814、LU6288、OLED。','最后按“图像预警、语音查询、网页监控、参数下发”四条链路做软硬件联调。']: numbered(doc,x)

doc.add_heading('8. 当前验收结论',1)
make_table(doc,['验收项','结论'],[
('软件页面展示','已完成，可模拟运行'),('后端 WebSocket','已完成基础版'),('SQLite 记录','已完成基础版'),('官方 YOLOv8 权重','已下载并加载验证'),('真实 YOLO 摄像头检测','待硬件/真实图像验证'),('FunASR/TTS','尚未完成'),('ESP32 可烧录实机固件','尚未实机验证'),('离线完整 AI 系统','尚未完成'),('最终安全性验收','尚未完成')])

doc.add_heading('9. 交接注意事项',1)
for x in ['不要把 SIMULATION_MODE=true 的结果当作真实 AI 或硬件数据。','不要在 ESP32 上加入 YOLO、FunASR、大模型或其他复杂 AI 推理。','不要在前端、固件或代码仓库硬编码大模型 API 密钥。','修改 GPIO 前必须以板卡原理图和实测资源为准。','模型文件较大，交接时应确认 backend/models/yolov8n.pt 是否随项目一起提供。','启动前先检查端口 8765 是否被旧进程占用。']: bullet(doc,x)

footer=sec.footer.paragraphs[0]; footer.alignment=WD_ALIGN_PARAGRAPH.CENTER; footer.add_run('启明帽项目开发交接文档  |  2026-11-16').font.color.rgb=RGBColor(100,100,100)
doc.core_properties.title='启明帽项目开发进度与后续开发交接文档'; doc.core_properties.subject='QimingHat software and hardware handoff'; doc.core_properties.author='QimingHat Development Team'
doc.save(OUT); print(OUT)
