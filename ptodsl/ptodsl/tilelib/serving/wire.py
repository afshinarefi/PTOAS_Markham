# Copyright (c) 2026 Huawei Technologies Co., Ltd.
# This program is free software, you can redistribute it and/or modify it under the terms and conditions of
# CANN Open Software License Agreement Version 2.0 (the "License").
# Please refer to the License for details. You may not use this file except in compliance with the License.
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
# See LICENSE in the root of the software repository for the full text of the License.
"""Wire framing for the TileLib daemon RPC.

Matches the legacy tilelang protocol exactly: a 4-byte big-endian length prefix followed
by a UTF-8 JSON payload, over an AF_UNIX SOCK_STREAM socket, one request per connection.
"""

from __future__ import annotations

import json


def recv_exactly(sock, n: int) -> bytes:
    chunks = []
    remaining = n
    while remaining > 0:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("socket closed mid-message")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def send_message(sock, obj: dict) -> None:
    payload = json.dumps(obj).encode("utf-8")
    sock.sendall(len(payload).to_bytes(4, byteorder="big"))
    sock.sendall(payload)


def recv_message(sock) -> dict:
    length = int.from_bytes(recv_exactly(sock, 4), byteorder="big")
    return json.loads(recv_exactly(sock, length).decode("utf-8"))


__all__ = ["send_message", "recv_message", "recv_exactly"]
