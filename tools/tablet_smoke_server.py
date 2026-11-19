"""Local-only tablet QA backend with an isolated, automatically removed database.

Run from the project root: python -m tools.tablet_smoke_server
This never creates a test account in the normal project database.
"""
import os
from pathlib import Path
import tempfile


def main():
    with tempfile.TemporaryDirectory(prefix='qiminghat-tablet-qa-') as folder:
        os.environ['DATABASE_PATH'] = str(Path(folder) / 'qa.sqlite3')
        from backend.database import init_db
        from backend.auth import register_user
        from backend.main import app
        import uvicorn

        init_db()
        register_user('tabletqa', 'tabletqa@example.invalid', 'Tabletqa123')
        print('Isolated tablet QA backend: http://127.0.0.1:18765')
        uvicorn.run(app, host='127.0.0.1', port=18765, log_level='warning')


if __name__ == '__main__':
    main()
