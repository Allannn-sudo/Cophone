# 部署与日常使用

## 1. 设备与账号

必须使用 **已越狱的 iPhone 4，系统为 iOS 6.1.3**。还需 Cydia Substrate、AppSync、OpenSSH、oldbili 2.0.6（Bundle ID `net.iosipa.oldbili`）。不同系统或 oldbili 版本不在本项目部署与验收范围。工程不包含 iOS SDK、第三方 App IPA 或个人账号；请自行准备。DeepSeek 用于目标理解、决策和摘要；阿里云百炼北京地域 Key 用于千问语音转写和生图。调用需要网络与平台额度。

## 2. 安装 cophone

1. 解锁 iPhone，通过 USB 连接电脑并允许访问。
2. 爱思助手或 iFunBox 选择 `artifacts/ios6/cophone-iOS6-0.10.0-shipping.ipa` 安装。已有新版时优先覆盖，不要先卸载，以保留配置和记录。
3. 主屏名称是 **cophone**。不安装早期“经典版”；内部 Bundle ID 为保持数据兼容仍保留 `ai.whaletech.cophone.classic`，它不代表需要装第二个 App。
4. 打开一次，确认底部“主页 / 记录 / 设置”可用。

## 3. 安装后台组件（Mac 一次性操作）

终端进入本目录：

```sh
brew install libimobiledevice libusbmuxd
python3 --version
python3 ios6/deploy.py --voice
```

安装器只发送本目录的自有 DEB，校验传输校验和，隐藏输入 SSH 密码；密码不保存、不进入命令行参数。默认使用 Mac 本地端口2224转发到手机22，可用 `--port` 更改。多设备时加 `--udid 设备ID`。不读取电脑或手机 API Key，不安装 IPA，也不自动刷新桌面。

默认安装：

| 组件 | 版本 | 用途 |
|---|---|---|
| cophone IPA | 0.10.0 | 主页、任务、设置、记录、相册保存 |
| 后台服务 | 0.4.0-24 | 手机 AI、使用回顾、Notes、任务规划及画面导出 |
| Safari 菜单 | 0.1.1 | 选文后确认摘要/配图 |
| oldbili 接入 | 0.2.1 | 真实 App 搜索、简介读取、实际 UIView 画面采集 |
| Home 语音 | 0.1.3 | 长按 Home 录音入口 |
| 完成通知跳转 | 0.1.3 | 点击直接进入对应笔记正文/单张图片，不经过cophone |

首次加载 Home / 通知跳转插件需要重新加载一次桌面或重启手机，两者一起安装可合并为一次。先保存内容，再通过越狱设备已有的重载工具手动执行；熟悉 SSH 的用户也可在自己确认后执行 `killall SpringBoard`。本安装器不会执行它。更新普通 IPA 不需要反复重载桌面。更新 Safari / oldbili 插件后，在多任务栏退出对应 App，下次打开会加载新插件；oldbili 日常任务可静默启动，不必每次手动预开。

## 4. 手机配置

发行包不含开发者Key，也不自动启用导入的旧凭据。使用者必须打开 cophone → 设置 → AI 设置，手动分别填写自己的 DeepSeek Key、千问/百炼北京 Key 并保存。Key 在手机私有 `Library/Application Support/cophone/ai-config.json` 中，权限0600并启用首次解锁后文件保护，不进入共享 Documents、投屏或安装包。首次配图按系统提示允许照片权限。手机直连官方 HTTPS，使用系统证书验证。自用包继续兼容原有配置，不包含在此交付目录中。

默认模型名称由现有配置决定；源码默认 `deepseek-flash`、`qwen-image-plus`，平台账号需要可访问相应模型。若平台返回模型/额度错误，以实际错误为准，不自动换模型或重放计费请求。

## 5. 日常操作

- **视频 Agent：** cophone 保留后台；长按 Home 或主页“交办任务”输入完整需求，核对后开始。在 Safari 等其他 App 正常使用。收到完成通知后核对 Notes。oldbili 正在前台时不会在用户当前页面搜索，需先切到其他 App。
- **整理摘录：** Safari 选中正文，点“整理成摘要 / 整理成图片”，核对并确认；摘要到 Notes，图片归入系统照片的 cophone 相簿。
- **目视官：** 主页 → 目视官 → 开始记录；正常浏览 Safari / oldbili，最后回桌面停留6秒，自动写回顾。读取可取得的网页/视频元数据，不宣称获取所有 App 内容。
- 强退 cophone 表示下线：菜单隐藏，后续操作停止；重新打开恢复。锁屏、通话、超时等不符合条件时不会强行抢占屏幕。

## 6. Mac 执行画面

USB 连接、解锁后双击“查看 cophone 执行画面.command”，或：

```sh
python3 ios6/live/viewer.py
```

启动器自动打开Mac默认浏览器的 `http://127.0.0.1:18770/`，不需要Codex。如果自动打开失败，复制该地址到Chrome/Safari即可。保持终端运行，退出请在该终端按Control+C。电脑只经 AFC 文件共享读取五个固定文件：`oldbili-state.json`、`agent-frame.json`、`agent-frame.png`、`execution-state.json`、`execution-image.png`；不需要 SSH 密码、不用 AI Key、不参与规划或 App 操作。实时帧过期或任务不匹配会标为等待/最后一帧，不伪造连续画面。关闭终端或拔掉 USB 仅停止观察。

窗口可切换找视频、摘要、配图和目视官。视频显示真实App画面；摘要显示确认选文和AI正文；配图显示手机实际收到的PNG和相簿验证；目视官显示读取到的应用、网页、视频分段及正文。后三种属于实际执行数据面板，不声称是第三方App截图。升级后若旧观察窗口还在运行，先在其终端按Control+C，再双击本次新版启动器。

## 7. 完成通知直接跳转

0.1.3已通过用户真机点击验收：指定视频推荐笔记直接进入正文，指定图片直接显示单张大图，均未闪过cophone。统一安装器默认包含这个插件，不需要另装IPA。仅处理cophone自己已保存并带交付UUID的完成通知；进度、失败、自检和其他应用通知保持原行为。

摘要、视频推荐、目视官的完成通知绑定保存回执里的系统笔记integerId；配图绑定已回读确认的资产UUID。每条通知定位自己的结果，不会因后续任务完成而改跳最新一条。升级前的旧通知没有定位标识，仍只打开对应App；结果已删除时系统可能退回默认页，不能恢复被删除内容。实现细节见 [结果定位](RESULT-NAVIGATION.md)。

本次用户设备已按明确授权加载，无需再次重载。新设备/首次更新系统插件需保存内容后手动重载一次。可用 `python3 ios6/deploy.py --skip-notification-route` 跳过安装；该选项不会卸载已有插件。

## 8. 清理与凭据

记录 → 清除 App 内历史记录 → 确认，清理本地任务、回顾、选文、执行画面及请求缓存；保留系统备忘录、相册、API设置和菜单开关。运行中会阻止清理，先完成或停止任务。设置 → AI设置 → 移除手机上的API Key，可撤销本机后续AI调用；任务运行时不可移除。GitHub包不含个人凭据，但把已配置过的手机交给别人时，应先移除自己的Key。

## 9. 排错

- SSH Broken pipe：检查手机连接和 OpenSSH 是否正常，保留错误，不反复猜密码。只重新执行失败的组件安装；不必卸载 IPA。
- 无画面：确认本轮确实发出视频任务、oldbili 2.0.6 已安装并加载0.2.1插件、cophone在线、手机解锁。只有进度和动作文字不等于画面通过。
- API失败：在手机检查网络、Key地域、模型权限和额度；不需要更改 Mac VPN。
- 系统插件异常：通过 SSH 移除本次新增的自有插件包，并在保存内容后恢复桌面；不要删除第三方插件或手机数据。通知插件包名 `ai.whaletech.cophone.notification-route`，语音插件包名 `ai.whaletech.cophone.voice`（以 DEB control 为准）。
