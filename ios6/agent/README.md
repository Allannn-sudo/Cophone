# cophone AI 任务 · 0.7.3

手机独立执行：不需要 Mac、USB、Codex 或代理。安装后，在手机 **AI 设置** 配置 DeepSeek API Key 与阿里云百炼**北京地域** API Key；输入框不显示旧密钥，不记录日志。Key 保存在本 App 私有 Library，不在文件共享 Documents，不写入 IPA。

## 使用

1. 手机保持 Wi-Fi 联网。Safari 等应用选择并复制 1–2000 字。
2. cophone 点 **用复制的文字做任务**，核对预览，选择 **摘要 → 备忘录** 或 **配图 → 相册**。
3. 生图首次需在前台允许相册权限，然后才提交计费请求。
4. 按 Home 继续浏览。手机服务直接调用国内 API；成功保存且回读一致后，回桌面可收到完成通知。
5. 如果长时间生成后 App 已被系统暂停，重新打开 cophone 接续已生成图片的相册保存；不会重新提交生图。

回顾与摘录任务独立：不必先开始回顾。AI 仅上传你明确确认的摘录，不携带浏览历史、缓存、账号或其他笔记。停止等待只阻止本机保存，不能撤回云端已提交请求或保证退费。

Safari 也可直接选择正文 → **整理成摘要 / 整理成图片** → 核对并确认；继续在浏览器使用即可，不必切回 cophone。该入口的安装与权限说明见 [Safari 菜单](../menu/README.md)。

## 实现

`AgentTasks.m` 预览文字并原子保存 UUID 请求。mobile 服务内 `PhoneAIWorker` 在独立线程使用 iOS6 的 NSURLConnection，经手机 Wi-Fi 直连官方 HTTPS。保留默认服务器证书校验；禁止重定向，不用信任所有证书的兼容办法。iOS6 真机无密钥连接已得到两个平台 HTTP401，确认 TLS 与证书校验可用。

`PhoneAIEngine` 在手机私有 `Library/Application Support/cophone/jobs` 保存每任务状态。POST 前写 submitting；收到千问 task ID 后保存，只进行 GET 查询。提交响应丢失或服务在 submitting 阶段中断，进入 uncertain，不自动重发计费请求。同 UUID 的内容不能变化；单服务串行处理。配置或任务错误不显示请求正文、Key、签名图片 URL。

摘要：DeepSeek → result_ready → 确认手机解锁（Safari 入口无需回桌面）→ Notes 本机新建 → 独立只读正文回读 → verified/completed → 通知。

配图：千问异步任务 → 手机下载官方 HTTPS PNG → 自己 Documents → IPA 校验 SHA256、大小与尺寸 → ALAssetsLibrary 保存 → 按 asset URL 回读 RGBA 像素 SHA256 → 添加到 **cophone 相簿** → 独立枚举该相簿确认同一 asset URL → verified/completed → 桌面通知。不得把复制文件到 DCIM 称为保存相册。原图1328×1328，不依赖 Mac 缩图；最多10MB、1600像素。

`PhotoAlbum.m` 查找同名相簿，存在则复用，没有则创建；新增资产后最多三次短延迟回读，不把 addAsset 返回值当作归档证明。保存后的 asset URL 与像素摘要是检查点：中断只继续归档，不能重复写入照片。归档失败保留 album_pending，明确提示照片已在相机胶卷，下次前台继续归档。覆盖0.6.1起可迁移上一次有回读凭据的配图，不扫描或搬动其他照片。专用相簿是对同一张照片的组织，系统相机胶卷仍显示它。[Apple 相簿说明](https://developer.apple.com/documentation/assetslibrary/alassetsgroup?language=objc)。

剪贴板入口的相册保存使用普通 App 的 beginBackgroundTask 时限，不伪装音频后台、不绕过相册权限。Safari 入口由服务启动已安装 cophone 的 --photo-worker，无界面执行已授权的相册保存，单次限90秒。后台下载和摘要由 mobile 服务完成；GUI 被暂停时保留结果，可重新打开后接续。相册保存中断的检查点避免重复插入：有 asset URL 就回读，无 URL 则停止并要求人工核对。

## 配置与故障

- DeepSeek 默认 `deepseek-flash`，明确关闭深度思考，输出约300–450字的知识卡片，分为原文要点与模型常识背景补充，后者不声称来自原文或联网核验。北京千问异步适配器默认 `qwen-image-plus`，1张1328×1328，仅支持 qwen-image-plus / qwen-image。
- **等待手机配置**：在 AI 设置保存对应 Key；尚未提交的同一任务会自动继续。
- **HTTP401/403/额度错误**：核对 API Key、地域、模型授权与额度；不会自动再次计费提交。不是千问聊天 App 登录凭据。
- **uncertain**：先在平台核对任务，不自动重复提交；任务ID已收到时则只继续查询。
- **相册未完成**：打开 cophone，保持片刻；权限被拒时到系统设置允许，先核对已有照片，避免重复保存。

旧 Mac `worker.py` 是0.5.0兼容工具；检测 `agent-transport.json` 的 phone 模式后不发请求，不参与0.6.0正常演示。`configure_phone.py` 只供开发期经已有USB SSH转发迁移本机配置；用户日常直接在App配置，不需要此脚本。

[千问 API](https://help.aliyun.com/zh/model-studio/qwen-image-api) · [DeepSeek API](https://api-docs.deepseek.com/) · [真机验证记录](../../docs/VALIDATION.md)
