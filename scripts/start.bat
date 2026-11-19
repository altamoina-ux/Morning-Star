@echo off
setlocal
cd /d "%~dp0.."
set "QIMING_CONDA=conda"
if defined CONDA_EXE if exist "%CONDA_EXE%" set "QIMING_CONDA=%CONDA_EXE%"
call "%QIMING_CONDA%" run --no-capture-output -n yolo-blind python -c "import uvicorn, fastapi, httpx, cv2, numpy, dotenv, pandas, openpyxl, ultralytics, websockets"
if errorlevel 1 (
    echo Conda or dependencies in yolo-blind are unavailable.
    echo conda run -n yolo-blind python -m pip install -r backend\requirements-conda.txt
    exit /b 1
)
call "%QIMING_CONDA%" run --no-capture-output -n yolo-blind python -m uvicorn backend.main:app --host 0.0.0.0 --port 8765
exit /b %errorlevel%
