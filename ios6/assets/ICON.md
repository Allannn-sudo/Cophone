# cophone 图标

0.9.3 IPA重新使用现有不透明方形原图`icon-master.png`，构建时用macOS sips输出57/114/29/58像素，不生成新的画作。由iOS施加圆角，`UIPrerenderedIcon`仅关闭系统高光。此前把旧越狱系统App的透明预裁圆角素材沿用到用户IPA，手机实际图标四周出现黑边；本次修正构建素材选择。包检查要求IPA图标全不透明，屏幕效果仍需覆盖安装后核对。

用户已确认0.9.3桌面黑边消失。0.9.4仅对App内页眉UIImageView启用`masksToBounds`并按宽度17.5%设置圆角，桌面PNG保持不透明；避免为修复页眉而再次引入桌面遮罩问题。

以下为停用的经典版素材历史，不能再用于用户IPA的主屏图标：

使用内置 imagegen 生成并编辑，随后用 macOS `sips` 缩放为安装尺寸。最初的方形原图为 `icon-master.png`；当前圆角原图为 `icon-rounded-master.png`，四角具有真实透明 alpha。57 / 114 像素用于主屏，29 / 58 像素用于较小图标。iPhone 4 Retina 使用 114 像素主屏图标。

0.2.0 实测以越狱系统 App 方式安装后，iOS 6 不会替这张图自动施加圆角遮罩，原先“由系统处理圆角”的假设不成立。0.2.1 已在 PNG 内预置圆角和透明四角，主体保留鲸鱼与时钟；构建检查验证 RGBA、四角 alpha=0、主体近乎不透明。系统图标服务回读取证也已确认圆角和透明四角。`UIPrerenderedIcon` 仍用于禁止系统重复添加高光。

以下首版提示词属于历史记录，其中“由系统处理圆角”的要求已被后续编辑替代。

最终生成提示词：

> Use case: logo-brand. Asset type: a final production iOS 6 home-screen app icon for CoPhone Classic, a background phone assistant experiment, on iPhone 4. Generate one square 1024x1024 full-bleed icon asset, not a mockup. A bold friendly turquoise whale silhouette, broad curved body and simple raised tail, centered on a deep midnight navy ocean-blue background. Integrate a very small warm amber clock badge at lower right, communicating quiet background scheduling. Tasteful 2012 iOS-era polished enamel with restrained soft highlights, clean sculptural curves, subtle dimensional depth, sophisticated rather than cartoon clutter. Extremely clear at 57x57 pixels. Whale occupies about 70% of canvas. Opaque color all the way to the square corners, do not pre-round the outside corners; the OS will mask them. No white background, no typography, no letters, no watermark, no device frame, no grid of variants. A single finished icon.

图标声明依据：[Apple CFBundleIconFiles / CFBundleIcons 文档](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html)。实际生成原图为 1254 × 1254，安装图标按确定尺寸缩放。


圆角版本编辑提示词（内置 imagegen，输入为 `icon-master.png`，透明背景开启）：

> Edit target: the supplied CoPhone app icon. Use case: precise-object-edit. Preserve the existing turquoise whale, gold clock badge, deep navy background, colors, lighting, details, and composition inside the icon. Change ONLY the outside boundary: apply a precise classic iOS 6 rounded-square corner mask, with circular corner radius approximately 17.5% of the full square side. The icon should fill the square canvas edge-to-edge along the straight parts of its edges, with no extra padding. The four areas cut off by rounded corners must be genuinely transparent alpha=0, NOT white, NOT black, NOT a painted checkerboard. Keep the deep navy background fully opaque within the rounded square. Crisp smooth antialiased edge. No shadow extending outside the icon, no border, no typography. A final standalone PNG app icon with true transparent corners for a jailbroken iOS 6 system app which does NOT apply its own mask.
