#!/usr/bin/env python3
"""
Standalone IDB entry point with embedded migrations code
"""
import sys
import os

# Set environment variable that IDB might need
os.environ['FB_IDB_VERSION'] = '1.1.3'

# Embed the python.migrations.py310 module code
try:
    from enum import StrEnum as StrEnum310
except ImportError:
    from enum import Enum
    class StrEnum310(str, Enum):
        pass

# Create the module structure that IDB expects
import types
python_module = types.ModuleType('python')
migrations_module = types.ModuleType('python.migrations')
py310_module = types.ModuleType('python.migrations.py310')

# Add the StrEnum310 to the py310 module
py310_module.StrEnum310 = StrEnum310

# Add modules to sys.modules so imports work
sys.modules['python'] = python_module
sys.modules['python.migrations'] = migrations_module
sys.modules['python.migrations.py310'] = py310_module

try:
    from idb.cli.main import main
    if __name__ == '__main__':
        sys.exit(main())
except ImportError as e:
    print(f"Error importing IDB: {e}", file=sys.stderr)
    print("Make sure IDB is properly installed", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error running IDB: {e}", file=sys.stderr)
    sys.exit(1)
