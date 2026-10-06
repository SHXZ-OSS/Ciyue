# 校内词典库（dict-cdn）

校内受管版 Ciyue 的词典来自学校自己的 CDN 索引库，默认地址：

```
https://dict-cdn.shxzhy.cn/index.json
```

（构建时可用 `--dart-define=DICT_LIBRARY_INDEX_URL=...` 覆盖。）

## index.json 格式

```json
{
  "format": 1,
  "dictionaries": [
    {
      "id": "oald-10",
      "name": "牛津高阶英汉双解词典（第10版）",
      "description": "可选的一句话描述",
      "version": "2026-09-01",
      "files": [
        {
          "name": "main.mdx",
          "url": "files/oald10.mdx",
          "sizeBytes": 812345678,
          "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        },
        {
          "name": "main.mdd",
          "url": "files/oald10.mdd",
          "sizeBytes": 412345678,
          "sha256": "..."
        }
      ]
    }
  ]
}
```

### 字段说明

| 字段 | 必填 | 说明 |
|---|---|---|
| `format` | ✅ | 固定为 `1`，其他值客户端拒绝解析 |
| `dictionaries[].id` | ✅ | 词典唯一标识，仅允许 `A-Za-z0-9._-`。同时用作本地安装目录名 |
| `dictionaries[].name` | ✅ | 展示名称 |
| `dictionaries[].description` | ❌ | 展示描述 |
| `dictionaries[].version` | ✅ | 任意字符串。与本地已装版本不同即显示"更新" |
| `dictionaries[].files[]` | ✅ | 至少一个 `.mdx`；`.mdd` 资源可选 |
| `files[].name` | ✅ | 同一词典的所有文件**必须同 stem**（如 `main.mdx` / `main.mdd` / `main.1.mdd`）。安装时会统一改名为 `<id>.<后缀>` 存放 |
| `files[].url` | ✅ | 绝对 URL，或相对 index.json 的路径（`files/oald10.mdx` 会解析为 `https://dict-cdn.shxzhy.cn/files/oald10.mdx`） |
| `files[].sizeBytes` | ✅ | 字节数，用于进度条与总大小展示 |
| `files[].sha256` | ❌ | 强烈建议填写。下载完成后校验，不匹配则安装失败并清理残留 |

## 客户端行为

- 入口：`设置 → 管理词典 → 右上角云朵图标`（主页无词典时也有入口按钮）。
- 下载到 `<应用私有目录>/dict_library/<id>/`，校验通过后走原有 MDX 导入管线，无需任何存储权限。
- 同一 `id` 的新 `version`：先自动卸载旧安装再导入新文件。
- `index.json` 建议设置较短的 `Cache-Control`（如 5 分钟），词典文件本体可以长缓存。

## 生成 sha256

```bash
sha256sum oald10.mdx
```
