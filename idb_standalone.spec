# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from PyInstaller.utils.hooks import collect_all

# Get the IDB module path
project_root = '/Users/bkessler/Apps/idb-main'
idb_path = os.path.join(project_root, 'idb')

# Add the project root to Python path so it can find the python.migrations module
sys.path.insert(0, project_root)

# Collect all IDB modules and data
datas, binaries, hiddenimports = collect_all('idb')

# Try to collect the python.migrations module
try:
    python_datas, python_binaries, python_hiddenimports = collect_all('python.migrations')
    datas += python_datas
    binaries += python_binaries
    hiddenimports += python_hiddenimports
except:
    # If collect_all fails, manually add the python directory
    python_dir = os.path.join(project_root, 'python')
    if os.path.exists(python_dir):
        for root, dirs, files in os.walk(python_dir):
            for file in files:
                if file.endswith('.py'):
                    file_path = os.path.join(root, file)
                    rel_path = os.path.relpath(file_path, project_root)
                    datas.append((file_path, os.path.dirname(rel_path)))

# Add additional data from other packages
grpclib_datas, grpclib_binaries, grpclib_hiddenimports = collect_all('grpclib')
protobuf_datas, protobuf_binaries, protobuf_hiddenimports = collect_all('protobuf')
aiofiles_datas, aiofiles_binaries, aiofiles_hiddenimports = collect_all('aiofiles')
treelib_datas, treelib_binaries, treelib_hiddenimports = collect_all('treelib')

# Try to collect pyre_extensions
try:
    pyre_datas, pyre_binaries, pyre_hiddenimports = collect_all('pyre_extensions')
except:
    pyre_datas, pyre_binaries, pyre_hiddenimports = [], [], []

# Combine all data and imports
datas += grpclib_datas + protobuf_datas + aiofiles_datas + treelib_datas + pyre_datas
binaries += grpclib_binaries + protobuf_binaries + aiofiles_binaries + treelib_binaries + pyre_binaries
hiddenimports += grpclib_hiddenimports + protobuf_hiddenimports + aiofiles_hiddenimports + treelib_hiddenimports + pyre_hiddenimports

# Add additional hidden imports for IDB dependencies
hiddenimports += [
    'pyre_extensions',
    'typing_extensions',
    'grpclib',
    'grpclib.client',
    'grpclib.server',
    'grpclib.const',
    'grpclib.events',
    'google.protobuf',
    'google.protobuf.internal',
    'google.protobuf.message',
    'google.protobuf.descriptor',
    'idb.cli.main',
    'idb.cli.commands',
    'idb.common.types',
    'idb.common.format',
    'idb.common.logging',
    'idb.grpc.idb_pb2',
    'idb.grpc.idb_grpc',
    'idb.grpc.client',
    'aiofiles',
    'aiofiles.base',
    'aiofiles.threadpool',
    'treelib',
    'treelib.tree',
    'treelib.node',
    'h2',
    'h2.connection',
    'h2.events',
    'h2.config',
    'h2.settings',
    'pkg_resources',
    # Add migrations-related imports
    'python',
    'python.migrations',
    'python.migrations.py310',
]

# Additional data files - include proto files if they exist
proto_file = os.path.join(project_root, 'proto', 'idb.proto')
if os.path.exists(proto_file):
    datas += [(proto_file, 'proto')]

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
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=None)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='idb',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)
