# cophone 完成通知跳转

当前 **0.1.3** 已安装，并在用户另一次明确授权后加载；`routeLoaded=1`、`clickHookReady=1`。用户已确认直接进入指定Notes已有正文及Photos单张大图、没有闪过cophone，已加入shipping默认部署。用户未分别注明横幅/通知中心入口，不扩大为两个入口均逐项验收。0.1.0/0.1.1 用户真实点击均仍先经过 cophone，不能宣称已修复。0.1.1的点击构造改写计数为0，尽管生成阶段修改计数为1。

## 本机实际系统链路

对用户设备iOS6 SpringBoard只读分析显示：`SBUserAgent.launchFromPushOrLocalBulletin:origin:` 根据 bulletin.sectionID 找到所属 App，设置它的 pending local notification，然后启动它。此路径忽略之前修改的 BBAction.launchBundleID。因此候选0.1.2改为只在此最终入口处理自有完成通知。

读取实际 bulletin.sectionID 与 context 中的 kBBBulletinContextUserInfoKey，用 RoutePolicy 校验本应用、交付UUID与固定完成动作。匹配后调用系统本地 `canLaunchFromBulletinWithURL:bundleID:` 和 `launchFromBulletinWithURL:bundleID:allowUnlock:animate:launchOrigin:`，目标仅为 Notes/Photos，保留原origin及系统解锁处理，不把cophone通知内容投递给目标App。无法启动时回退原方法；其他通知直接走原方法。未自行调用SBS RPC、未绕过PIN验证，不在通知送达时切换App。

接入前核对上述3个方法及BBBulletin getter的真实类型编码；不匹配不hook。仅SpringBoard加载，独立于已验收Home语音插件。

## 构建与部署

```sh
python3 ios6/notifications/test_policy.py
python3 ios6/notifications/build_route.py
python3 ios6/notifications/verify_route.py
```

策略、精确结果URL和作用域检查共43项，包为armv7/SHA1签名，无安装/重载脚本。静态检查不替代实际点击；本轮两种目标已有用户目视验收。

`python3 ios6/notifications/install_route.py` 更新自有后台与通知插件，不安装IPA、不自动重新加载桌面。首次激活要在保存内容并明确允许后手动重载一次。统一shipping部署现已默认包含0.1.3；当前用户设备已加载，无需再次安装/重载。

`CheckRoute` 只发送自有无AI测试通知，读routeLoaded/clickHookReady及匹配/实际路由计数。分别实测顶部横幅与通知中心、Notes与Photos，并目视确认无cophone闪屏。仅计数增加不能代替用户目视验收。

## 撤回

移除自有包 `ai.whaletech.cophone.notification-route` 后，在保存内容后重新加载桌面；不要删除语音插件、App数据或其他插件。结果保存和原App跳转回退不依赖此候选。

精确定位：Notes的Spotlight URL数字是ZINTEGERID/NoteObject.integerId，不能使用Z_PK；Photos使用assets-library回执中的UUID。每条通知自带经过严格校验的结果URL，URL被拒绝时退回直接打开目标App。新系统插件只在用户明确同意后加载，后台服务更新无需重载。
