# oldbili 接入

目标：接受自然语言任务，在真实 oldbili 内搜索、读取候选并比较，实际写入系统备忘录；收藏仅在登录与保存回读可验证后开放。后台搜索与自然语言搜索/比较/备忘录整轮均已真机通过；不能宣称所有 App 或任意弹窗都受支持。

已从用户正在使用的真机确认：`net.iosipa.oldbili` 2.0.6，首页根控制器为 `RootTabBarViewController`。另一个 1.0.13 安装未作为当前目标。

## 接入方式

`OldbiliAdapter.m` 由 Cydia Substrate 仅加载到指定版本的 oldbili 进程。使用已核对 Objective-C 类型编码的 `SearchViewController`，创建不接入任何 UIWindow/导航栈的独立控制器。在 App 进入后台后调用它自己的 `searchForKeyword`，观察 `searchEnd` 和加载状态。不发送坐标点击，不拉起 App，不使用另写的 B 站搜索 HTTP 客户端代替 App 操作。

这是一条有边界的语义操作路线，并非任意 App 的通用视觉点击方案。独立控制器不会呈现在用户正在看的 oldbili 页面上。后续答辩需如实展示 App 内部方法、真实状态观测与结果回读，不能把它称为逐屏视觉操作。

后台通过 suspended launch 静默唤起指定 oldbili，并申请最长135秒的有限后台执行许可；无需每次先打开 oldbili。解锁桌面上前台标识为 nil 是正常状态，不再误报为锁屏。锁屏、接口未就绪或 oldbili 正在前台时停止，不承诺常驻。到期明确报错。cophone 在线状态通过现有手机本地认证接口检查。私有桥接目录仅为 `oldbili/Library/Caches/cophone-agent`，命令带插件会话、UUID、30 秒有效期和固定动作白名单。版本/签名不匹配时拒绝调用。

当前接入支持只读搜索和候选简介读取；搜索结果限制 10 条，只提取视频 ID、标题、UP 主、时长、播放数和简介。账号信息、Cookie、Keychain、原始请求头均不读取、不导出。真实搜索已经在后台返回 10 条结果，用户确认 Safari 无干扰。0.8.0 接入手机 DeepSeek 自然语言规划、候选简介读取、比较与 Notes 回读，整轮已通过真机验收；不接入视频播放、完整视频详情页或收藏。

## 实际执行画面（0.2.1）

只截取Agent独立的真实SearchViewController，使用UIView.layer.renderInContext生成320×460 PNG，约每秒1帧；不截取用户前台窗口、不显示新窗口。后台服务将当前命令的帧和时间/任务ID导出到cophone文件共享，Mac用`ios6/live/viewer.py`只读显示；旧帧和不同任务不标为实时。本轮已导出真实后台列表PNG并获用户确认Mac显示真实列表。

## 开发检查

- `python3 ios6/oldbili/build_probe.py`：临时只读接口元数据插件。已移除手机中的该包。
- `python3 ios6/oldbili/build_adapter.py`：后台搜索接入层 DEB，无安装脚本、无 respring。
- `InspectBinary.m`：仅两个固定 App 的二进制接口元数据，或 cophone 自己写入的探针/接入层文件。
- `read_runtime.py`：USB SSH 检查，只在隐藏输入终端读取密码；不保存密码。

本轮开发可用 Mac 部署与检查；最终自然语言任务必须由手机独立运行。旧命令行搜索仅用于接入验证；最终入口为 cophone → 交办任务 → 用一句话找视频。

`OldbiliAgent.m` 执行有界观察—决策—操作循环；`AgentPolicy.m` 校验固定动作及真实候选ID，`test_policy.py` 的23项检查覆盖伪造ID、越权动作、重复读取和未读取就完成。最多7次AI决策、135秒，不自动重放中断的计费请求；以系统Notes独立回读作为完成条件。

## 桌面任务修复（后台服务 0.4.0-17）

失败轨迹 `3F15FF71-1E82-46F9-A95D-9A24461DD15F`：已完成 search/read，但模型在 inspected 状态连续提出 read，原错误将字段与状态问题混在一起，一次纠错后失败。现每轮提供 allowedActions，明确 inspected 时应 finish、search 或 stop；字段错误与重复读取分别给出纠错信息。仍禁止伪造 ID、未读就完成和执行已拒绝的操作。

同目标新任务 `5EDB4CC7-DF95-44AF-B7E4-267ADB59EFDC` 已真机完成 search(10条) → read(3条) → finish(2条)，系统备忘录 `cophone 视频推荐 · 10-10 11:42:53` 回读 verified=true。此轮由部署检查提交任务；此后用户另行确认已在桌面完成测试且没有问题。后台服务 0.4.0-18 起，新笔记使用实际比较主题作为标题，不再统一使用上述固定名称。
