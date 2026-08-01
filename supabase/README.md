# Supabase 初始化

## 执行第一版数据库迁移

1. 打开 Supabase 项目控制台。
2. 进入 `SQL Editor`，新建查询。
3. 打开 `migrations/202608010001_initial_schema.sql`，复制全部内容到查询窗口。
4. 执行查询，确认没有错误。

匿名公开密钥只能让 Flutter 客户端按照 RLS 规则读写数据，不能创建表。执行迁移不需要把数据库密码交给客户端。

## Flutter 连接参数

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://你的项目编号.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=你的可发布连接密钥
```

URL 必须是项目根地址，不要附加 `/rest/v1/`。

## 正式网页地址

部署到 Netlify 后，把 Netlify 生成的网址填入 Supabase 的 `Authentication -> URL Configuration`：

- `Site URL`：正式网页地址。
- `Redirect URLs`：正式网页地址及其登录回跳地址。
