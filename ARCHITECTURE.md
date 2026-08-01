# 模块职责

| 模块 | 职责 |
|---|---|
| `lib/main.dart` | 启动 Flutter 应用。 |
| `lib/app.dart` | 配置应用主题和根页面。 |
| `lib/core/config/supabase_config.dart` | 从编译参数读取 Supabase 公开连接配置。 |
| `lib/features/auth` | 处理注册、登录和登录状态切换。 |
| `lib/features/home` | 提供日程、健康和个人中心的主导航。 |
| `lib/features/schedule` | 读取日程、创建和删除任务、更新完成状态，并订阅日程变化自动刷新。 |
| `lib/features/health` | 读取训练状态、饮食、体重并写入云端，提供常用训练动作、组次数和个人常用食物选择，订阅健康记录变化自动刷新。 |
| `lib/core/feedback/user_message.dart` | 将认证、网络和数据库错误转换为中文用户提示。 |
| `supabase/migrations` | 维护可追踪的云端数据库结构升级。 |
| `.env.example` | 说明本机需要填写的 Supabase 公开连接配置。 |

# 调用关系

```text
Flutter 页面 -> Supabase 登录与数据接口 -> PostgreSQL 数据库
                         -> Realtime 同步 -> 其他已登录设备
```

# 关键决定

- 所有业务数据都通过 `user_id` 绑定 Supabase 登录账号。
- 数据库使用行级权限，客户端只能读写自己的数据。
- 饮食记录保存当时的热量和营养素快照，后续修改食物库不会篡改历史。
- 常用食物仅由用户自己维护；选择食物后，应用按基准份量换算营养数据。
- 日程和健康页面各自建立实时订阅，页面离开时主动关闭连接，避免重复订阅。
