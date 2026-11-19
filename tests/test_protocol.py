import struct

def test_binary_header_layout():
    header = b"QH" + bytes([1, 1]) + struct.pack("<H", 26) + struct.pack("<I", 7) + struct.pack("<Q", 1) + struct.pack("<HHI", 0, 1, 3)
    assert header[:4] == b"QH\x01\x01"
    assert struct.unpack_from("<H", header, 4)[0] == 26
    assert struct.unpack_from("<I", header, 22)[0] == 3
