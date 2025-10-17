#!/usr/bin/env python3
"""
Standalone IDB entry point for PyInstaller bundle
"""
import sys
import os

# Set environment variable that IDB might need
os.environ['FB_IDB_VERSION'] = '1.1.3'

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
