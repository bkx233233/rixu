<<<<<<< HEAD
# 日序

日序是一款同时支持 Android 和网页使用的个人生活管理应用。它把每天的日程、任务完成情况、饮食、训练和体重记录放在同一个账号中，并在不同设备之间同步。饮食支持保存自己的常用食物，后续选择食物即可自动带入营养数据。

## 技术架构

- Flutter：Android 与网页界面。
- Supabase：账号、PostgreSQL 数据库、数据权限和实时同步。已打开的设备会在日程、饮食、训练和体重记录变化后自动刷新。
- GitHub：保存代码和自动发布流程。

## 本地运行

安装 Flutter 后，在项目根目录执行。Supabase URL 使用项目根地址，不要填写带 `/rest/v1/` 的 REST 地址；连接密钥使用 Publishable key，不要使用 `secret` 密钥。

```powershell
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=你的项目地址 --dart-define=SUPABASE_PUBLISHABLE_KEY=你的可发布连接密钥
```

Android 打包命令：

```powershell
flutter build apk --release --dart-define=SUPABASE_URL=你的项目地址 --dart-define=SUPABASE_PUBLISHABLE_KEY=你的可发布连接密钥
```

## 数据库部署

使用 Supabase CLI 登录并关联项目后执行：

```powershell
supabase db push
```

如果通过 Supabase 网页控制台管理数据库，在 SQL Editor 按文件名顺序执行 `supabase/migrations` 中尚未执行的迁移。当前新增的 `202608020003_food_items.sql` 会建立“我的常用食物”并为饮食记录增加食物引用。

## 网页正式发布

本地 `flutter run -d chrome` 只用于开发，生成的 `localhost` 地址不能给手机长期访问。正式发布使用 Netlify，电脑不需要持续开机。

项目已经提供 `.github/workflows/deploy-web.yml`。将代码推送到 GitHub 的 `main` 或 `master` 分支后，GitHub Actions 会自动构建并发布网页。

需要在 GitHub 仓库的 `Settings -> Secrets and variables -> Actions` 添加：

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `NETLIFY_AUTH_TOKEN`
- `NETLIFY_SITE_ID`

Netlify 只托管 Flutter 生成的静态网页，账号和业务数据仍然保存在 Supabase。

## 测试

```powershell
flutter test
flutter analyze
```

## 搜索记录

第一版只支持用户手动录入、常用食物和最近记录，避免使用无法核验的营养数据。

## 待办

- 在 Supabase SQL Editor 执行 `supabase/migrations/202608020001_training_status_guard.sql` 和 `supabase/migrations/202608020002_realtime_workout_exercise_logs.sql`。
- 在 Supabase SQL Editor 执行 `supabase/migrations/202608020003_food_items.sql` 后，再使用常用食物功能。
- 如果训练状态显示“健身中”但动作仍保存失败，执行 `supabase/migrations/202608020004_fix_training_guard.sql` 覆盖旧的训练保护函数。
- 完成真实云端同步、网页发布与 APK 签名打包验证。
=======
# rixu
>>>>>>> 8f7be4c4bd0b41bc3c2567484bbf63b7c63c0fb2
