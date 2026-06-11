@echo off
REM ============================================================
REM  Swap the hero scroll-video.
REM
REM  EASIEST: drag a video file and drop it onto this .bat file.
REM  OR run from a terminal:
REM      tool\swap-video.bat "C:\path\to\your-video.mp4"
REM
REM  It re-encodes the clip for smooth scrubbing and drops it into
REM  web\media\scene.mp4. Afterwards, refresh the website.
REM ============================================================
if "%~1"=="" (
  echo Drag a video file onto this .bat, or pass a path as the first argument.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0prep_video.ps1" -Source "%~1"
echo.
echo Done. Refresh your browser (Ctrl+F5) to see the new video.
pause
