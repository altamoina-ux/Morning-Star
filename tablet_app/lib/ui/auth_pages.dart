import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/app_controller.dart';
import 'common.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.visibility_outlined, size: 52, color: accent),
                const SizedBox(height: 16),
                Text(
                  '启明帽',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '智能视觉辅助 · Android 平板端',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 32),
                Panel(child: child),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.app});
  final AppController app;
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  late final _server = TextEditingController(
    text: widget.app.preferences.server,
  );
  bool _busy = false;
  String? _error;
  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.app.connect(_server.text);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message.toString()
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('连接电脑后端', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          '平板与电脑连接同一 Wi-Fi。识字和 YOLO 在电脑运行，语音在平板播放。',
          style: TextStyle(color: muted, height: 1.7),
        ),
        const SizedBox(height: 24),
        if (_error != null) Notice(_error!),
        if (widget.app.notice != null) Notice(widget.app.notice!),
        TextField(
          controller: _server,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: '电脑后端地址',
            hintText: 'http://192.168.1.10:8765',
          ),
          onSubmitted: (_) {
            if (!_busy) _connect();
          },
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _connect,
          icon: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lan_outlined),
          label: Text(_busy ? '正在连接…' : '测试连接并继续'),
        ),
        const SizedBox(height: 20),
        const Text('电脑启动命令（在项目根目录）：', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        const SelectableText(
          'conda run --no-capture-output -n yolo-blind python -m uvicorn backend.main:app --host 0.0.0.0 --port 8765',
          style: TextStyle(fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 12),
        const Text(
          '在电脑执行 ipconfig 查 IPv4 地址。真实平板不能填 127.0.0.1；Android 模拟器可用 http://10.0.2.2:8765。HTTP 仅用于可信局域网调试，正式部署请配置 HTTPS。',
          style: TextStyle(color: muted, fontSize: 12, height: 1.7),
        ),
      ],
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.app});
  final AppController app;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _captcha = TextEditingController();
  Map<String, dynamic>? _challenge;
  bool _busy = false;
  bool _loadingCaptcha = false;
  bool _remember = true;
  bool _obscure = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
  }

  Future<void> _refreshCaptcha() async {
    if (_loadingCaptcha) return;
    setState(() {
      _loadingCaptcha = true;
      _challenge = null;
    });
    try {
      final challenge = await widget.app.api!.map(
        '/api/auth/captcha',
        authenticated: false,
      );
      if (challenge['captcha_id'] is! String || challenge['image'] is! String) {
        throw const ApiFailure('验证码接口格式错误，请检查电脑后端。');
      }
      if (mounted) {
        setState(() {
          _challenge = challenge;
          _captcha.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCaptcha = false);
    }
  }

  Future<void> _login() async {
    if (_name.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _captcha.text.trim().isEmpty) {
      setState(() => _error = '请输入账号、密码和验证码。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.app.login(
        name: _name.text,
        password: _password.text,
        captchaId: _challenge!['captcha_id'] as String,
        captcha: _captcha.text,
        remember: _remember,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        await _refreshCaptcha();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _captchaImage() {
    if (_loadingCaptcha) {
      return const SizedBox(
        width: 150,
        height: 46,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_challenge == null) return const Text('点此获取验证码');
    try {
      return SvgPicture.memory(
        base64Decode((_challenge!['image'] as String).split(',').last),
        width: 150,
        height: 46,
        semanticsLabel: '图形验证码，点击刷新',
      );
    } catch (_) {
      return const Text('验证码无法显示，请刷新');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('登录管理平台', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            widget.app.api!.baseUrl,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          if (widget.app.notice != null) Notice(widget.app.notice!),
          if (_error != null) Notice(_error!),
          TextField(
            controller: _name,
            enabled: !_busy,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              labelText: '账号',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? '显示密码' : '隐藏密码',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _captcha,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: '验证码'),
                  onSubmitted: (_) {
                    if (!_busy && _challenge != null) _login();
                  },
                ),
              ),
              Semantics(
                button: true,
                label: '刷新图形验证码',
                child: InkWell(
                  onTap: _busy || _loadingCaptcha ? null : _refreshCaptcha,
                  child: _captchaImage(),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            value: _remember,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('记住登录（本机安全存储）', style: TextStyle(fontSize: 14)),
            onChanged: _busy
                ? null
                : (value) => setState(() => _remember = value ?? false),
          ),
          FilledButton(
            onPressed: _busy || _challenge == null || _loadingCaptcha
                ? null
                : _login,
            child: Text(_busy ? '正在登录…' : '登录'),
          ),
          const SizedBox(height: 16),
          const Text(
            '账号与电脑网页端通用。首次使用请在电脑网页的登录页注册。',
            style: TextStyle(color: muted, fontSize: 13, height: 1.7),
          ),
          TextButton(
            onPressed: _busy ? null : widget.app.changeServer,
            child: const Text('修改电脑后端地址'),
          ),
        ],
      ),
    ),
  );
}
