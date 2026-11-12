"""Build a deterministic, self-contained UI review ZIP. Uses only Python stdlib."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/design/ui-system'


def asset_url(path):
    path = path.resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError(f'Asset outside repository: {path}')
    types = {'.png': 'image/png', '.ttf': 'font/ttf'}
    mime = types[path.suffix.lower()]
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode('ascii')


def build(output):
    html = (SOURCE / 'index.html').read_text()
    css = (SOURCE / 'ui.css').read_text()

    def inline_url(match):
        ref = match.group(1).strip('"\' ')
        if ref.startswith(('#', 'data:')):
            return match.group(0)
        if '://' in ref:
            raise ValueError(f'External stylesheet dependency: {ref}')
        return 'url("' + asset_url(SOURCE / ref) + '")'

    css = re.sub(r'url\(([^)]+)\)', inline_url, css)
    html = html.replace('<link rel="stylesheet" href="ui.css">', '<style>' + css + '</style>')
    for name in ['sample-data.js', 'decision-support.js', 'ui.js']:
        script = (SOURCE / name).read_text()
        if re.search(r'</script', script, re.I):
            raise ValueError(f'Inline script terminator in {name}')
        html = html.replace(f'<script src="{name}"></script>', '<script>\n' + script + '\n</script>')
    if re.search(r'<script[^>]+src=|<link[^>]+stylesheet', html, re.I):
        raise ValueError('Unbundled script or stylesheet')
    # Every style/font/image dependency is embedded; file:// needs no local server.
    entries = {
        'grayriver-ui.html': html.encode('utf-8'),
        'START-HERE.txt': ('灰河谷 UI 原型 v1.2\n\n解压后双击 grayriver-ui.html，用 Chrome、Edge 或 Firefox 打开。\n'
                           '不需要 Python、Godot、服务器或网络。推荐窗口至少960×720。\n'
                           '顶部按钮切换评审视图；I行囊、G选材、M地图、Esc返回。\n'
                           '所有状态为原型样例，刷新即重置，不连接正式游戏存档。\n'
                           '完整说明：https://github.com/llaaoo/mygame/blob/main/docs/design/ui-system/README.md\n').encode('utf-8'),
        'licenses/Noto-OFL.txt': (ROOT / 'content/art/fonts/OFL.txt').read_bytes(),
        'licenses/Puny-CC0.txt': (ROOT / 'content/art/third_party/puny/MIRROR_LICENSE.txt').read_bytes(),
        'licenses/ASSET-LEDGER.md': (ROOT / 'content/art/THIRD_PARTY_ASSETS.md').read_bytes(),
        'licenses/provenance.json': (SOURCE / 'provenance.json').read_bytes(),
    }
    inputs = ['index.html', 'ui.css', 'sample-data.js', 'decision-support.js', 'ui.js', 'world.png']
    manifest = {'kind': 'Offline design review only; not a Godot build',
                'html_sha256': hashlib.sha256(entries['grayriver-ui.html']).hexdigest(),
                'inputs_sha256': {name: hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() for name in inputs},
                'embedded_font': 'Unmodified NotoSansSC.ttf; original OFL included',
                'runtime_network_dependencies': 0}
    entries['manifest.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, content in entries.items():
            info = zipfile.ZipInfo(name, date_time=(2026, 11, 12, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, content, compresslevel=9)
    print(json.dumps({'path': str(output), 'bytes': output.stat().st_size,
                      'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=SOURCE / 'downloads/grayriver-ui-v1.2.zip')
    build(parser.parse_args().out)
