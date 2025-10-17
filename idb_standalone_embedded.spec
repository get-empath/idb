# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from PyInstaller.utils.hooks import collect_all

project_root = '/Users/bkessler/Apps/idb-main'
sys.path.insert(0, project_root)

# Collect all IDB modules
datas, binaries, hiddenimports = collect_all('idb')

# Add other dependencies
grpclib_datas, grpclib_binaries, grpclib_hiddenimports = collect_all('grpclib')
protobuf_datas, protobuf_binaries, protobuf_hiddenimports = collect_all('protobuf')
aiofiles_datas, aiofiles_binaries, aiofiles_hiddenimports = collect_all('aiofiles')
treelib_datas, treelib_binaries, treelib_hiddenimports = collect_all('treelib')

try:
    pyre_datas, pyre_binaries, pyre_hiddenimports = collect_all('pyre_extensions')
except:
    pyre_datas, pyre_binaries, pyre_hiddenimports = [], [], []

# Combine dependencies
datas += grpclib_datas + protobuf_datas + aiofiles_datas + treelib_datas + pyre_datas
binaries += grpclib_binaries + protobuf_binaries + aiofiles_binaries + treelib_binaries + pyre_binaries
hiddenimports += grpclib_hiddenimports + protobuf_hiddenimports + aiofiles_hiddenimports + treelib_hiddenimports + pyre_hiddenimports

# Add essential hidden imports
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
]

a = Analysis(
    ['idb_main_embedded.py'],
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
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='idb_embedded',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)
