#!/usr/bin/env python3
"""End-to-end check: python3 + pyzbar + libzbar on Alpine 3.8 (musl).

pyzbar finds libzbar through ``ctypes.util.find_library('zbar')`` and loads
it at import time.  This script:

  1. resolves libzbar.so.0 with find_library(),
  2. imports pyzbar (which loads the shared library), and
  3. renders qr_matrix.txt (a QR code for "PYZBAR-ALPINE38-OK")
     into a raw 8-bit grayscale buffer and decodes it again with pyzbar.

No Pillow/numpy is needed: pyzbar also accepts a (pixels, width, height)
tuple.  Exit status 0 means the whole chain works.
"""

import os
import sys
from ctypes.util import find_library

from pyzbar.pyzbar import decode, ZBarSymbol
from pyzbar.zbar_library import load as load_zbar

HERE = os.path.dirname(os.path.abspath(__file__))
MATRIX_PATH = os.path.join(HERE, 'qr_matrix.txt')
TEXT = 'PYZBAR-ALPINE38-OK'
SCALE = 8


def load_matrix(path):
    """Read the 0/1 QR matrix (1 = black module, quiet zone included)."""
    rows = []
    with open(path) as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(line)
    if not rows:
        raise ValueError('empty matrix: {0}'.format(path))
    width = len(rows[0])
    if any(len(row) != width for row in rows):
        raise ValueError('non-rectangular matrix: {0}'.format(path))
    return rows


def render_gray(rows, scale):
    """Render a module matrix to an 8-bit grayscale (pixels, width, height)."""
    height = len(rows) * scale
    width = len(rows[0]) * scale
    pixels = bytearray(b'\xff' * (width * height))
    for y, row in enumerate(rows):
        for x, module in enumerate(row):
            if module != '1':
                continue
            for dy in range(scale):
                base = (y * scale + dy) * width + x * scale
                pixels[base:base + scale] = b'\x00' * scale
    return bytes(pixels), width, height


def main():
    lib = find_library('zbar')
    print('find_library("zbar") = {0!r}'.format(lib))
    if not lib:
        print('FAIL: libzbar.so.0 is not visible to the dynamic loader')
        return 1

    libzbar, _dependencies = load_zbar()
    print('pyzbar loaded libzbar from: {0}'.format(libzbar._name))

    pixels, width, height = render_gray(load_matrix(MATRIX_PATH), SCALE)
    print('test image: {0}x{1}, {2} bytes'.format(
        width, height, len(pixels)))

    results = decode((pixels, width, height), symbols=[ZBarSymbol.QRCODE])
    for result in results:
        print('decoded: type={0} data={1!r}'.format(
            result.type, result.data))

    ok = any(result.data.decode('utf-8') == TEXT for result in results)
    print('RESULT: {0}'.format('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
