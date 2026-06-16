@echo off
cd /d "%~dp0"
echo PUBG Stats — local server
echo URL: http://localhost:8080/stats.html
echo Press Ctrl+C to stop.
echo.
start "" "http://localhost:8080/stats.html"
python -m http.server 8080
