# cophone 语音入口 · 0.9.2

状态：App 内语音识别、追问、确认后真实oldbili任务/备忘录已通过；0.9.2无需预开oldbili的整轮任务及主屏无干扰也获用户确认。长按Home插件0.1.2首次加载后曾导致桌面卡死，已卸载恢复。0.1.3经再次同意安装加载，用户确认桌面/App正常、Safari长按Home录音框出现、取消与单/双按正常；取消后无遗留WAV。系统入口完整AI任务已由用户在解锁桌面验收通过；下线回退仍需单独验收，不以就绪标志替代。

**故障与修复：** 0.1.2的`available`在SpringBoard主线程同步调用SBS查询锁屏状态，存在向自身主线程RPC造成死锁的路径，是本次卡死的疑似原因，尚无线程栈证明。0.1.3把锁屏、网络和通话状态采样全部移至异步线程；主线程手势处理只读取快照，2.5秒未更新自动失效。锁屏查询另有主线程拒绝守卫。10项快照/过期回归及源代码调用路径检查通过，21项语音协议检查通过。已真机验证稳定性与手势，完整任务已在桌面验收；下线回退单独验收。

```mermaid
flowchart LR
 H[长按 Home / App 语音交办] --> R[主动录音 最长15秒]
 R --> Q[手机直连千问转写]
 Q --> D[DeepSeek 整理目标 / 追问]
 D --> C[用户确认]
 C --> A[现有 oldbili Agent]
 A --> N[Notes 保存及回读]
 N --> B[完成通知]
```

**安装：** 最新IPA为0.9.4，保留手机现有cophone并手动覆盖；不要安装故障插件0.1.2。“安装 iPhone 语音入口.command”指向0.1.3，只更新自己的服务及插件，不安装IPA、不自动重载桌面。首次加载需明确同意；本机0.1.3已加载，不必重复安装或刷新。已有千问与DeepSeek私有手机配置复用，不重新输入密钥。

**测试顺序：**

1. cophone → 交办任务 → 语音交办 → 取消，核对不发请求。
2. 说“帮我找视频” → 说完了，应追问主题。继续说主题，确认后才执行。
3. 确认已安装 oldbili 2.0.6，无需先打开，直接交办具体任务；确认后切到 Safari，核对真实 Notes 与通知。
4. 插件首次加载后，长按 Home 重复验证。单按/双按保持原行为；强退 cophone 后长按 Home 应恢复系统语音控制。

**边界：** 仅支持找视频、比较、推荐及写备忘录；不支持收藏、登录或任意 App 操作。App 必须在线、手机解锁且无通话；设置可关闭语音入口。每轮oldbili后台执行许可最多135秒，结束/下线/超时释放。录音会发给千问，目标与转写发给 DeepSeek；仅用户主动触发录音，不持续监听。取消已发请求不能承诺取消云端计费。音频存在手机私有 Library，读取后删除；Key 不传给 SpringBoard 插件，不进入 IPA、Documents 或日志。

**构建：** 先 `python3 ios6/build.py`，再 `python3 ios6/review/build_service.py`、`python3 ios6/voice/build_voice.py`。检查：`python3 ios6/voice/test_protocol.py`、`python3 ios6/voice/verify_voice.py`、`python3 ios6/review/verify_service.py`、`python3 ios6/verify_build.py`。ASR 格式依据[千问官方文档](https://help.aliyun.cn/zh/model-studio/qwen-asr-api-reference)。
