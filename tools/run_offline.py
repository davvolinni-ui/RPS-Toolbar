from pathlib import Path
import sys
from tempfile import TemporaryDirectory

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'tools' / '.deps'))
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().ROOT = root.as_posix()
with TemporaryDirectory(prefix='rps-toolbar-test-') as fixture:
    resource = Path(fixture)
    apps = [('ReaBrowse', 'ReaBrowse.lua'), ('ReaDrumXT', 'ReaDrum.lua'),
            ('ReaRoll', 'ReaRoll.lua'), ('ReaSpect', 'ReaSpect.lua')]
    rows = [f'SCR 4 0 RS{i} "Custom: {file}" {name}/{file}'
            for i, (name, file) in enumerate(apps, 1)]
    (resource / 'reaper-kb.ini').write_text('\n'.join(rows), encoding='utf-8')
    lua.globals().RESOURCE = resource.as_posix()
    lua.execute((root / 'tools' / 'offline.lua').read_text(encoding='utf-8-sig'))
