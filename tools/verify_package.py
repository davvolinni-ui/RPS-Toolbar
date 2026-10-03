"""Verify the ReaPack install tree, optionally checking published URLs."""
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from urllib.parse import unquote, urlparse
from urllib.request import urlopen
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'tools' / '.deps'))
from lupa.lua54 import LuaRuntime

index_bytes = (root / 'index.xml').read_bytes()
index = ET.fromstring(index_bytes)
revision = index.get('commit')
sources = index.findall('.//source')
assert len(sources) == 7
assert sum(s.get('main') == 'main' for s in sources) == 1
assert {s.get('file') for s in sources} == {
    'RPS Toolbar.lua', 'src/app.lua', 'src/icons.lua', 'src/launcher.lua',
    'src/order.lua', 'src/theme.lua', 'EULA.md'}

with TemporaryDirectory(prefix='rps-toolbar-install-') as temporary:
    installed = Path(temporary) / 'Scripts' / 'RPS Toolbar'
    for source in sources:
        file = source.get('file')
        assert unquote(urlparse(source.text).path).endswith(f'/{revision}/{file}')
        content = subprocess.check_output(['git', 'show', f'{revision}:{file}'], cwd=root)
        if '--remote' in sys.argv:
            with urlopen(source.text, timeout=30) as response:
                assert response.read() == content, f'Published source mismatch: {file}'
        target = installed / file
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    lua = LuaRuntime()
    lua.globals().INSTALL = installed.as_posix()
    lua.execute("package.path=INSTALL..'/?.lua;'..package.path; assert(loadfile(INSTALL..'/RPS Toolbar.lua')); assert(require('src.app').new); assert(require('src.launcher').activate)")
print('PASS: ReaPack install tree contains all runtime modules and EULA; entry parses and modules load')
if '--remote' in sys.argv:
    with urlopen('https://raw.githubusercontent.com/davvolinni-ui/RPS-Toolbar/main/index.xml', timeout=30) as response:
        assert response.read() == index_bytes, 'Published index mismatch'
    print('PASS: published index and all seven pinned downloads match the verified Git revision')
