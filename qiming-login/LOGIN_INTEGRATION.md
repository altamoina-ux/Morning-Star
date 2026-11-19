# 启明登录界面移植包

## 文件

- `login.html`: 登录/注册页面及全部样式
- `login.js`: 登录、注册、验证码、校验、状态持久化和表单切换逻辑
- `login-config.js`: 目标项目配置
- `assets/qiming-hat-hero.png`: 左侧帽子视觉素材

## 接入

将这四个文件复制到目标项目同一目录，并在 `login-config.js` 设置：

```js
window.QIMING_LOGIN_CONFIG = {
  apiBase: '',                 // 认证接口所在服务，例如 https://api.example.com
  successUrl: '/dashboard.html' // 登录成功后的页面
};
```

页面请求以下接口（接口返回 JSON）：

- `GET /api/auth/captcha` -> `{ captcha_id, image }`
- `GET /api/auth/session` -> 登录状态有效时返回 2xx
- `POST /api/auth/login` -> `{ token, user }`
- `POST /api/auth/register` -> `{ registered: true, username }`

登录接口请求体包含 `username`、`password`、`captcha_id`、`captcha`、`remember`；注册接口请求体包含 `username`、`email`、`password`、`confirm_password`、`captcha_id`、`captcha`、`terms`。

接口需要允许登录页来源跨域访问时，请在目标后端配置 CORS，并确保 `Authorization: Bearer <token>` 可用。

## 本项目使用

当前项目直接访问 `http://127.0.0.1:8765/login.html`，保持 `apiBase: ''` 和 `successUrl: '/'` 即可。
