"""Pone `lambda/src` en el path para que los tests puedan `import agent.*`."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "src"))
