import pytest

from backend.tts_protocol import speech_command


def test_speech_command_matches_working_lu6288_text_mode():
    assert speech_command("左侧有行人") == b"T<G>" + "左侧有行人".encode("gbk")


@pytest.mark.parametrize("text", ["", "  ", "有行人" * 33000], ids=["empty", "whitespace", "oversized"])
def test_speech_frame_rejects_empty_or_oversized_text(text):
    with pytest.raises((ValueError, UnicodeEncodeError)):
        speech_command(text)
