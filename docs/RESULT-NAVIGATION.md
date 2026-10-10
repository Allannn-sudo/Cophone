# 点击完成通知定位具体结果

2026-10-10：通知插件0.1.3、后台0.4.0-24；43项路由策略检查通过。用户已分别确认直接进入指定已有笔记正文和指定单张图片，均未闪过cophone；无需更新或卸载IPA。默认交付包已经更新。

## 实现链路

- 摘要、视频推荐、目视官：保存同一UUID笔记并独立回读标题/正文，再取得系统的ZINTEGERID，并与NoteObject.integerId核对。Z_PK只是Core Data存储行号，第一次候选误用它进入新建页，真机反馈后修正。
- Notes没有注册普通URL scheme；使用系统Spotlight的 `search://com.apple.mobilenotes/<编号>` 分发，由Notes现有handleOpenURL入口按数字记录编号恢复指定笔记。
- 配图：从已完成像素/相簿回读的AssetsLibrary资产URL提取UUID，生成系统Photos支持的 `photos://asset?uuid=<UUID>`，由PhotosURLNavigationRequest定位单张图片。
- 每条完成通知携带自己的结果URL与交付UUID，不在点击时读取“最新任务”，所以多条完成通知不会互相串结果。SBUserAgent直接选择系统App与结果URL，不经过cophone界面。
- 仅接受固定Notes/Photos目标与严格校验的编号/UUID格式；其他通知不改变。缺失或拒绝的结果链接退回打开目标App。旧通知没有结果链接，不能自动补写成精确定位；已删除的笔记/图片也无法恢复。

## 验收与角标

本轮按用户明确授权只重载一次桌面；修正笔记编号及角标更新仅安装普通后台服务，不再重载。测试使用既有cophone结果，不调用AI或生成新图。Notes与照片的精确定位均通过用户目视确认。

后台角标迁移已通过真机目视验证：完成横幅仍归cophone管理，后台通过iOS 6原生SpringBoardServices接口设置目标App角标，不产生额外横幅；查看后只清除cophone写入的待查看角标状态。首轮静默通知方案未显示；改用原生接口后用户已确认备忘录和照片均显示红色1，打开对应App后自动清除，cophone无红点，详见STATUS。
