# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from PyInstaller.utils.hooks import collect_all

project_root = '/Users/bkessler/Apps/idb-main'
sys.path.insert(0, project_root)

# Collect all modules
datas, binaries, hiddenimports = collect_all('idb')

# Manually add the python.migrations module
python_dir = os.path.join(project_root, 'python')
if os.path.exists(python_dir):
    for root, dirs, files in os.walk(python_dir):
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, project_root)
                datas.append((file_path, os.path.dirname(rel_path)))

# Add other dependencies
grpclib_datas, grpclib_binaries, grpclib_hiddenimports = collect_all('grpclib')
protobuf_datas, protobuf_binaries, protobuf_hiddenimports = collect_all('protobuf')
aiofiles_datas, aiofiles_binaries, aiofiles_hiddenimports = collect_all('aiofiles')
treelib_datas, treelib_binaries, treelib_hiddenimports = collect_all('treelib')

try:
    pyre_datas, pyre_binaries, pyre_hiddenimports = collect_all('pyre_extensions')
except:
    pyre_datas, pyre_binaries, pyre_hiddenimports = [], [], []

datas += grpclib_datas + protobuf_datas + aiofiles_datas + treelib_datas + pyre_datas
binaries += grpclib_binaries + protobuf_binaries + aiofiles_binaries + treelib_binaries + pyre_binaries
hiddenimports += grpclib_hiddenimports + protobuf_hiddenimports + aiofiles_hiddenimports + treelib_hiddenimports + pyre_hiddenimports

hiddenimports += [
    'pyre_extensions', 'typing_extensions', 'grpclib', 'grpclib.client',
    'google.protobuf', 'idb.cli.main', 'idb.common.types', 'idb.grpc.client',
    'python', 'python.migrations', 'python.migrations.py310',
    'aiofiles', 'treelib', 'h2', 'pkg_resources'
]

a = Analysis(
    ['idb_main.py'],
    pathex=[project_root],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'numpy', 'scipy'],
    cipher=None,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=None)

exe = EXE(
    pyz,
    a.scripts,
    exclude_binaries=True,
    name='idb',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    target_arch='arm64',
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    name='idb_bundle',
)
