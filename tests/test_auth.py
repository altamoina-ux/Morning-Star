import base64

import pytest
from fastapi import HTTPException

from backend import auth, database
from backend.config import settings


@pytest.fixture
def auth_db(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "database_path", str(tmp_path / "auth.sqlite3"))
    database.init_db()


def test_captcha_is_one_time_and_session_round_trip(auth_db):
    captcha = auth.create_captcha()
    image_data = captcha["image"].split(",", 1)[1]
    svg = base64.b64decode(image_data).decode("utf-8")
    assert "<text x=" in svg
    code = auth._captchas[captcha["captcha_id"]][0]
    auth.verify_captcha(captcha["captcha_id"], code.lower())
    with pytest.raises(HTTPException):
        auth.verify_captcha(captcha["captcha_id"], code)

    auth.register_user("careuser", "care@example.com", "Care123")
    with database.db() as connection:
        stored = connection.execute(
            "SELECT password_hash FROM auth_users WHERE username = ?", ("careuser",)
        ).fetchone()["password_hash"]
    assert stored != "Care123"
    assert auth.session_username(auth.create_session("careuser", "Care123", False)["token"]) == "careuser"

