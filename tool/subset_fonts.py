"""Keep Latin, Cyrillic and punctuation using Flutter's bundled font-subset."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('Flutter is not on PATH')
sdk = Path(flutter).resolve().parent.parent
subsetters = list((sdk / 'bin/cache/artifacts/engine').glob('*/font-subset'))
if not subsetters:
    raise SystemExit('Run flutter doctor to cache font-subset first')
ranges = [(32, 0x024F), (0x0400, 0x052F), (0x2000, 0x206F),
          (0x20A0, 0x20CF), (0x2100, 0x214F)]
points = ' '.join(f'optional:{c}' for a, b in ranges for c in range(a, b + 1))
measurements = []
with tempfile.TemporaryDirectory() as tmp:
    for font in sorted((ROOT / 'assets/fonts').glob('Roboto-*.ttf')):
        before = font.stat().st_size
        output = Path(tmp) / font.name
        subprocess.run([str(subsetters[0]), str(output), str(ROOT / 'tool/fonts-original' / font.name)],
                       input=points + '\n', text=True, check=True)
        shutil.copyfile(output, font)
        measurements.append({'file': font.name, 'beforeBytes': before,
                             'afterBytes': font.stat().st_size})
print(json.dumps(measurements, ensure_ascii=False, indent=2))
