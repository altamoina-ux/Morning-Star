"""LU6288 text-mode UART commands based on the working SSCOM test."""


def speech_command(text: str) -> bytes:
    """Build the ``<G>`` GBK text command, prefixed for the camera WS link."""
    if not isinstance(text, str) or not text.strip():
        raise ValueError("speech text cannot be empty")
    content = text.strip().encode("gbk")
    if len(content) > 240:
        raise ValueError("speech text is too long")
    return b"T<G>" + content
