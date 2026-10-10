# 构建、配置与检查

Mac需要Python3、Xcode命令行工具（clang和ld-classic）、支持armv7的旧iPhoneOS SDK。SDK不随工程分发；把合法取得的SDK放在本机并指定路径。工程使用Theos格式9.3 SDK构建armv7/iOS6目标，链接时在本地输出目录调整TAPI stub切片，原SDK不被修改。现代不含armv7的SDK不能直接替代。

```sh
export IOS_LEGACY_SDK=/absolute/path/to/iPhoneOS9.3.sdk
python3 ios6/build.py --edition shipping
python3 ios6/verify_build.py
python3 ios6/review/build_service.py
python3 ios6/review/verify_service.py
python3 ios6/menu/build_menu.py
python3 ios6/menu/verify_menu.py
python3 ios6/oldbili/build_adapter.py
python3 ios6/voice/build_voice.py
python3 ios6/voice/verify_voice.py
```

先构建App会生成 `artifacts/ios6/sdk`，其他组件使用同一链接SDK。IPA、DEB使用armv7和SHA-1 ad-hoc签名，因此仅用于上述越狱测试设备，不适用于App Store或普通未越狱iPhone。`/Applications/Xcode.app/...` 为默认工具链路径，Xcode安装到其他位置时修改 `ios6/build.py` 中的 `TOOLS`。

有针对性的检查：

```sh
python3 ios6/oldbili/test_policy.py
python3 ios6/oldbili/test_background_launch.py
python3 ios6/review/test_native.py
python3 ios6/review/test_note_presentation.py
python3 ios6/voice/test_protocol.py
python3 ios6/voice/test_availability.py
python3 ios6/live/test_viewer.py
python3 ios6/tests/test_private_state.py
python3 ios6/release/audit.py .
```

部分检查依赖macOS Foundation或本机原生编译器；静态/原生检查不代替iPhone实际操作和屏幕核验。没有在工程中硬编码个人API Key。手机运行不需要Mac `.env`；Key在手机设置中填写。部署可用 `--udid`、`--port`；旧组件安装脚本还接受 `COPHONE_IOS_UDID` 和 `COPHONE_REVIEW_SSH_PORT`，优先用统一的 `ios6/deploy.py`。

本目录包含可直接安装的当前IPA/DEB，无需为了使用而重新编译。`SHA256SUMS.json` 记录交付文件SHA256；更新工程后需要重新生成清单。调试助手代码保留用于说明接口检查过程，但不包含读取出的苹果系统二进制、第三方App二进制、个人使用轨迹或密钥。

发行构建默认 `--edition shipping`，生成文件名带 shipping 的IPA，Info.plist中 `CophoneRequireManualAPI=true`。只有设置页保存Key才会写入对应手动配置标记；摘要、生图、语音、视频规划均校验此策略。自用构建 `--edition personal` 继续使用手机已保存的配置，产物不放入GitHub交付目录；两种IPA都不内置Key。
