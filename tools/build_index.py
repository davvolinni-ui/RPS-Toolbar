"""Generate an immutable ReaPack release index from a committed revision."""
from pathlib import Path
from datetime import datetime, timezone
import re
import subprocess
from urllib.parse import quote
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
REPO = 'https://raw.githubusercontent.com/davvolinni-ui/RPS-Toolbar'
SUPPORT = 'https://forum.cockos.com/showthread.php?t=311768'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

revision = git('rev-parse', 'HEAD')
entry = 'RPS Toolbar.lua'
version = re.search(r'^-- @version (\S+)', (ROOT / entry).read_text(encoding='utf-8-sig'), re.M)[1]
files = [entry, *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'src').glob('*.lua')), 'EULA.md']
for file in files:
    committed = subprocess.check_output(['git', 'show', f'{revision}:{file}'], cwd=ROOT)
    local = (ROOT / file).read_text(encoding='utf-8-sig')
    assert committed.decode('utf-8-sig').replace('\r\n', '\n') == local, f'Uncommitted release content: {file}'
path = ROOT / 'index.xml'
index = ET.parse(path).getroot() if path.exists() else ET.Element('index', version='1', name='RPS Toolbar')
index.set('commit', revision)
category = index.find('category')
if category is None:
    category = ET.SubElement(index, 'category', name='RPS Toolbar')
package = category.find('reapack')
if package is None:
    package = ET.SubElement(category, 'reapack', name=entry, type='script', desc='RPS Toolbar - customizable icon launcher')
    metadata = ET.SubElement(package, 'metadata')
    ET.SubElement(metadata, 'link', rel='website').text = SUPPORT
    ET.SubElement(metadata, 'link', rel='website').text = 'https://github.com/davvolinni-ui/RPS-Toolbar'
    ET.SubElement(metadata, 'description').text = r'{\rtf1\ansi RPS Toolbar by Davvo. Requires ReaImGui 0.10 and JS_ReaScriptAPI. Install controlled apps separately. Read the included EULA.md before use.}'
assert not any(v.get('name') == version for v in package.findall('version')), 'Version already indexed; increment @version before publishing another release'
release = ET.SubElement(package, 'version', name=version, author='Davvo', time=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))
ET.SubElement(release, 'changelog').text = 'Initial public ReaPack release.'
for file in files:
    attrs = {'file': file}
    if file == entry:
        attrs['main'] = 'main'
    ET.SubElement(release, 'source', **attrs).text = f'{REPO}/{revision}/{quote(file, safe="/")}'
ET.indent(index, space='  ')
ET.ElementTree(index).write(path, encoding='utf-8', xml_declaration=True)
print(f'Indexed RPS Toolbar {version}: {len(files)} files pinned to {revision}')
