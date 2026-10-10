# iOS 6 白色桌面图标排查

安装包文件正确、应用可启动、uicache 正常退出，并不等于 SpringBoard 正在展示新图标。0.2.0 已出现实际反例：用户可以进入 App，但主屏仍为首次安装时的白色占位图。

本次已取得的证据：

1. 手机 App 内四张 PNG 都存在，安装后的逐文件校验与本机构建一致。
2. 系统 `com.apple.mobile.installation.plist` 中 CoPhone 的名称、版本、路径和图标声明均已更新。
3. PNG 是 8-bit RGB；iOS 6 的 UIImage 实际解码通过：57/114 主屏、29/58 较小图标，Retina scale=2 正常识别。
4. USB SpringBoard 图标服务返回的 CoPhone 图标仍是白色。仅取此 App 的图标，不读取整张手机屏幕或其他 App 的图标。
5. 可用的 `LSApplicationWorkspace invalidateIconCache:` 接受了 CoPhone 的单应用刷新请求，但再次回取仍为白色。尚不能因此断定问题已解决。

读取实际系统图标（只读，Mac 安装 libimobiledevice）：

```bash
python3 ios6/icon_probe.py --udid YOUR_UDID --output artifacts/ios6/springboard-icon.png
```

可选诊断工具 `build_icon_tool.py` 构建 `src/icon_refresh.m`，在越狱手机的临时目录运行。默认仅验证图片解码和查询缓存刷新方法是否存在，`--refresh` 请求仅失效 CoPhone 缓存并发送应用安装通知。私有 API 在运行时检查可用性；此工具属于安装/排查流程，不参与后台日历任务，也不改变任务执行的能力边界。

用户保存工作并明确同意后，向 SpringBoard 发送 HUP 重新加载桌面，再次通过 USB 回取 CoPhone 系统图标，已恢复为鲸鱼时钟图。证据为 `artifacts/ios6/icon-after-desktop-reload.png`；本次修复无需改动 App、清空整个 Caches 目录、删除 IconState 或恢复主屏布局。

今后若遇到同类问题，重载可能中断当前 App 并回到锁屏，应先让手机操作者保存内容。不能用“重载命令已执行”代替最终图标回读或用户目视确认；此例是重载后实际回读图标确认恢复。

安装器现已区分 `uicache_command_succeeded` 与 `icon_appearance_verified`，避免把登记命令完成误报为图标实际更新。本次诊断后 `install-status.json` 已记录图标验证通过。修复前的证据为 `artifacts/ios6/icon-before.png` 和 `icon-after-target-refresh.png`。

## 图标已显示但没有圆角

以越狱系统 App 安装时，0.2.0 的方形底图没有获得预期的系统圆角遮罩。0.2.1 已在四种 PNG 里直接提供透明圆角；构建时检查 alpha，安装后再通过系统图标服务回读确认。当前实际图标证据为 `artifacts/ios6/icon-rounded-device.png`。圆角遮罩现在是资源本身的一部分，不依赖系统在运行时自动处理。

参考：[UIKit Tools 的图标缓存实现](https://github.com/coolstar/uikittools-theos/blob/master/uicache.mm)、[libimobiledevice SpringBoard 图标服务接口](https://github.com/libimobiledevice/libimobiledevice/blob/master/include/libimobiledevice/sbservices.h)。
