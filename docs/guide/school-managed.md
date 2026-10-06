# 校内受管部署（行知·慧云 MDM）

本文说明校内受管版 Ciyue 的服务端配置。App 侧逻辑：

- **登录与身份**：通过设备管理客户端（`com.shxzhy.mdm`）的免授权身份接口获取当前学生与后端地址，`server_url` 每次实时获取、不缓存。
- **同步**：学生在 `设置 → 学校同步` 手动点一次"授权并同步"（MDM 授权页，已授权过的学生 3 秒倒计时自动放行）。之后每次启动若本地 token 有效则静默同步，绝不主动发起新授权。
- **同步内容**：生词本（含标签）、闪卡及复习记录，走后端 appdata 文件存储（`/api/appdata/files/...`），命名空间为"学生 + 本应用"，多设备自动合并、冲突保留双方版本。
- **词典**：从校内 CDN 索引库下载，见[校内词典库](/guide/dict-library.md)。

## 服务端清单

1. **OAuth 应用注册**（行知·慧云后台 → OAuth 应用管理）：
   - `client_id`：`ciyue`（如需自定义，构建时用 `--dart-define=MDM_CLIENT_ID=...` 覆盖）
   - 类型：**公共客户端**（PKCE S256，无 client_secret）
   - `redirect_uri`：`ciyue://oauth/callback`
   - scope：`openid profile`
   - 开启 **AppData 存储**，MIME 白名单放行 `application/json`（同步快照为 JSON 文件）
   - 单文件大小上限：同步快照很小，默认值即可

2. **受管应用清单**：将本应用包名加入 `/api/mdm/apps` 下发清单，否则 MDM 两个入口都会静默拒绝（身份返回空、授权提示"该应用未获授权"）。

3. **词典 CDN**：按 [index.json 格式](/guide/dict-library.md) 部署到 `https://dict-cdn.shxzhy.cn/`。

## 构建要点

- 仅 Android 受管场景可用 OAuth 同步；其他平台该设置页仅显示提示。
- 更新检查、AI（解释/翻译/写作批改/聊天）、原 WebDAV/SFTP/S3 云同步均已移除；WebView 阻断词典内容中的一切远程资源加载。
