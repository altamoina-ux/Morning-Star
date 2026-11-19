import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/app_controller.dart';
import 'common.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.app});
  final AppController app;
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _devices;
  String? _error;
  bool _busy = false;
  bool _active = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_active) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _refresh();
  }

  Future<void> _refresh() async {
    if (_busy || !widget.app.loggedIn) return;
    setState(() => _busy = true);
    try {
      final data = await widget.app.api!.request('/api/tablet/devices');
      if (data is! List) throw const FormatException('设备接口格式不正确，请检查后端版本。');
      if (mounted) {
        setState(() {
          _devices = data
              .map((d) => Map<String, dynamic>.from(d as Map))
              .toList();
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeading(
          '设备管理',
          '帽端连接与最近心跳 · 每 10 秒更新',
          action: IconButton(
            tooltip: '刷新设备',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (_error != null)
          Notice('$_error${_devices == null ? '' : ' 下方为上次记录，在线状态可能已变化。'}'),
        if (_busy && _devices == null)
          const Center(child: CircularProgressIndicator()),
        if (_devices?.isEmpty ?? false)
          const Panel(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.sensors_off, size: 48, color: muted),
                  SizedBox(height: 20),
                  Text('暂无帽端设备', style: TextStyle(fontSize: 22)),
                  SizedBox(height: 12),
                  Text(
                    '先使用平板摄像头体验识字和检测。帽端完成后，按现有固件协议连接电脑后端即可在此看到设备。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
        ...?_devices?.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.sensors, color: accent, size: 30),
                      Text(
                        '${device['name'] ?? device['device_id']}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      StatusPill(
                        device['online'] == true ? '在线' : '离线',
                        good: device['online'] == true && _error == null,
                      ),
                      if (device['simulation'] == true)
                        const StatusPill('模拟设备'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    '设备编号：${device['device_id']}\n固件：${device['firmware_version'] ?? '未上报'}\n最近心跳：${timeLabel(device['last_heartbeat'])}',
                    style: const TextStyle(color: muted, height: 1.9),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '在线表示当前后端设备连接仍存在。摄像头、麦克风、扬声器和振动电机尚无可靠的自检上报，需在硬件联调时逐项验证。平板图像上传不会伪装成帽端在线。',
          style: TextStyle(color: muted, height: 1.7, fontSize: 13),
        ),
      ],
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.app});
  final AppController app;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _autoRead = widget.app.preferences.autoRead;
  late double _rate = widget.app.preferences.rate;
  double? _confidence;
  bool _busy = false;
  String? _error;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.app.api!.map('/api/tablet/config');
      final value = data['confidence'];
      if (value is! num || value < .05 || value > .95) {
        throw const FormatException('检测配置格式不正确。');
      }
      if (mounted) setState(() => _confidence = value.toDouble());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveConfidence() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.app.api!.map(
        '/api/tablet/config',
        method: 'PUT',
        data: {'confidence': _confidence},
      );
      if (mounted) setState(() => _message = '检测置信度已保存，将用于后续检测。');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocal(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = '本机设置保存失败，请检查应用存储空间后重试。');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.app.speech,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeading('系统设置', '连接地址、平板播报与检测参数'),
        if (_error != null)
          Notice(
            _error!,
            action: TextButton(
              onPressed: _busy ? null : _load,
              child: const Text('重试'),
            ),
          ),
        if (_message != null) Notice(_message!),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '电脑后端',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              SelectableText(
                widget.app.api!.baseUrl,
                style: const TextStyle(fontSize: 18, color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                '当前账号：${widget.app.username}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.app.changeServer,
                    icon: const Icon(Icons.lan_outlined),
                    label: const Text('修改连接地址并重新登录'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.app.logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('退出登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '平板本机语音',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (widget.app.speech.error != null)
                Notice(widget.app.speech.error!),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _autoRead,
                title: const Text('识别完成后自动朗读'),
                onChanged: (value) {
                  setState(() => _autoRead = value);
                  _saveLocal(() => widget.app.preferences.setAutoRead(value));
                },
              ),
              Text(
                '语速：${(_rate * 100).round()}%',
                style: const TextStyle(color: muted),
              ),
              Slider(
                value: _rate,
                min: .2,
                max: .7,
                divisions: 10,
                label: '${(_rate * 100).round()}%',
                onChanged: (value) => setState(() => _rate = value),
                onChangeEnd: (value) => _saveLocal(() async {
                  await widget.app.preferences.setRate(value);
                  await widget.app.speech.setRate(value);
                }),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      await widget.app.speech.initialize(_rate);
                      await widget.app.speech.speak('启明帽已准备好，为您识别文字并朗读。');
                    },
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('测试中文播报'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.app.speech.stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('停止播报'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '使用 Android 系统 TTS。无声音时请检查媒体音量、蓝牙输出，以及系统「文字转语音」中的中文语音包。是否支持离线播报取决于所选语音引擎；本项目没有内置语音包。',
                style: TextStyle(color: muted, height: 1.7, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '电脑端检测参数',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
              if (_confidence != null) ...[
                Text(
                  '置信度阈值：${(_confidence! * 100).round()}%',
                  style: const TextStyle(color: muted),
                ),
                Slider(
                  value: _confidence!,
                  min: .05,
                  max: .95,
                  divisions: 18,
                  label: '${(_confidence! * 100).round()}%',
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _confidence = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveConfidence,
                    child: const Text('保存检测参数'),
                  ),
                ),
              ] else if (!_busy)
                TextButton(onPressed: _load, child: const Text('重新读取检测参数')),
              const SizedBox(height: 12),
              const Text(
                '此参数影响电脑后端的所有图像来源。阈值越高，低置信度检测越少。',
                style: TextStyle(color: muted, height: 1.7, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '关于与硬件接入',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                '启明帽平板端 0.1.0\n当前模式：平板采集 / 电脑 AI / 平板播报。\n后续帽端接入现有 /ws/device 协议；帽端扬声器播放识别文字还需要接通音频下发和硬件播放链路。',
                style: TextStyle(color: muted, height: 1.9),
              ),
              const SizedBox(height: 12),
              SelectableText(
                '本机图像来源：${widget.app.sourceId}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
