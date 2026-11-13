# 本轮引入的第三方视觉素材

这些文件随游戏源码本地分发，运行时不访问外部网站。以下许可允许商业使用；它们不要求购买订阅或启用 GitHub Actions。仓库原有美术不在本轮新增素材清单内。

| 素材 | 作者 / 来源 | 许可与项目用途 |
|---|---|---|
| Tiny Town，192×176 PNG | [Kenney 官方目录](https://kenney.nl/assets/tiny-town)，[实际下载镜像](https://github.com/Two-Weeks-Team/openClawWorld/blob/main/packages/client/public/assets/kenney/tiles/tinytown_tilemap.png) | CC0 / public domain；灰河谷草地、道路局部纹理、树、屋顶、墙、木桶、路牌、井与铺石。PNG未修改；绘制时裁切、拼接、缩放、调色。 |
| Lucide SVG 图标 | [Lucide](https://lucide.dev/)，[上游源码](https://github.com/lucide-icons/lucide) | ISC，部分继承图标采用 MIT；保留完整[上游许可](third_party/lucide/LICENSE)。用于菜单、动作、物品类别与状态。SVG的`currentColor`换成固定中性色；Godot按3倍导入，再线性采样。 |
| Noto Sans SC 可变字体 | [Google Fonts / Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) | SIL Open Font License 1.1；原始TTF未修改，保留[OFL与版权声明](fonts/OFL.txt)。UI通过Godot FontVariation选择450字重，包含中文字符，未生成或重命名字体衍生版本。 |

每个实际下载文件的来源 URL、原始 SHA-256、落盘 SHA-256、体积与改动说明见 [visual_assets.json](third_party/visual_assets.json)。完整 Noto 中文字体约17.8 MB，选择保留中文覆盖而非裁切子集。

Kenney 图集来自公开镜像。镜像的 [ASSET_MAP.md](https://github.com/Two-Weeks-Team/openClawWorld/blob/main/ASSET_MAP.md) 标明包名和 CC0；作者的官方目录和[支持说明](https://kenney.nl/support)同样标明公共领域与可商用。云环境能读取官方页面的索引信息，但无法直接下载官方站点压缩包，因此没有伪称拿到了原包的许可文件。[CC0_NOTICE.txt](third_party/kenney/CC0_NOTICE.txt)是本项目记录来源的说明，明确不是上游许可原件；CC0条款见 [Creative Commons](https://creativecommons.org/publicdomain/zero/1.0/)。自愿署名不代表作者为本项目背书。

游戏内入口：Tab → 操作设置 → 素材与许可。发布时应一并保留本目录内的版权和许可文件。

复核下载内容，无网络依赖：

```bash
python3 - <<'PY'
import hashlib, json
from pathlib import Path
for row in json.loads(Path('content/art/third_party/visual_assets.json').read_text()):
    path = Path(row['path'])
    assert path.stat().st_size == row['bytes'], path
    assert hashlib.sha256(path.read_bytes()).hexdigest() == row['vendored_sha256'], path
print('Third-party asset hashes verified')
PY
```

## 动画样本

新增Shade的Puny Characters三张原始PNG（合计75,088字节），CC0，可商业使用。实际下载源为固定提交的公开镜像，二次镜像对象散列一致；完整许可、镜像说明、修改边界及逐文件散列保存在[puny目录](third_party/puny/SOURCE_NOTICE.md)与[动画清单](third_party/puny/animation_assets.json)。正式身体只采样无武器列，原图刀/弓/法杖动作仅在参考预览展示。游戏内Tab → 操作设置 → 动画与素材演示可查看；详情见[动画基座](../../docs/ACTOR_ANIMATION_SYSTEM.md)。
## 世界表现样本

水井原生场景复用上述Kenney图集，角色复用上述Puny素材；没有新增来源不明的网络素材。营火、树摆、波纹与原生粒子由项目代码和Godot资源制作。4个原创合成WAV以CC0分发，完整来源/重建方法/散列见[声音说明](../presentation/sounds/SOURCE_NOTICE.md)；它们是集成样本，不是环境录音或完整拟音库。

## 物品插画生成样本

16件现有物品接入一张原创AI生成图集，用作列表、快捷栏与行囊大图，未导入新的第三方画作。原图未编辑，Godot按区域采样；来源、输出条款、散列与穿戴表现边界见[样本说明](items/grayriver/SOURCE_NOTICE.md)。这些生成输出不归入上面的第三方CC0清单。
