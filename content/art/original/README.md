# 原创兽类占位图

`hound.svg`、`crawler.svg` 是本项目原创的八方向四足占位图，由 `tools/build_beast_animation_assets.py` 在本地生成，无外部下载、商标或第三方素材。它们仅包含身体，不绘制装备。每行一个方向，每列为 idle / walk / bite / hurt / death 的帧，配套原生 SpriteFrames 和 ActorAnimationProfile 复用公共表现 rig。

可随项目商业使用、修改与替换。运行时不运行生成器，也不联网。它们用于验证敌人与身体表现通路，后续可用正式美术替换贴图和动画资源，保留领域动作与 UID 规则。
