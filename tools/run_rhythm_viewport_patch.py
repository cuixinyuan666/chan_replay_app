from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    for script in ['tools/apply_rhythm_viewport_selector_patch.py', 'tools/validate_rhythm_viewport_page_patch.py']:
        print('running', script)
        subprocess.run([sys.executable, script], cwd=ROOT, check=True)
    print('run_rhythm_viewport_patch: OK')


if __name__ == '__main__':
    main()
