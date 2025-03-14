@echo off
setlocal enabledelayedexpansion

REM Set colors for Windows console
set "GREEN=[32m"
set "WHITE=[97m"
set "RED=[31m"
set "NC=[0m"

REM Always use CPU mode on Windows since we're not handling GPU detection
set OLLAMA_GPU_DRIVER=cpu

REM Check if Ollama is running
curl -s http://100.92.237.90:11434/api/version >nul 2>&1
if errorlevel 1 (
    echo %RED%Error: Ollama is not running on 100.92.237.90:11434%NC%
    echo Please make sure Ollama is running before starting Open WebUI
    exit /b 1
)

echo %WHITE%Current Setup:%NC%
echo    %GREEN%GPU Driver:%NC% %OLLAMA_GPU_DRIVER%
echo    %GREEN%Ollama URL:%NC% %OLLAMA_BASE_URL%
echo    %GREEN%WebUI Port:%NC% 3000
echo.

REM Remove GPU configuration since we're not using it on Windows
type docker-compose.local-ollama.yaml | findstr /v "deploy:" | findstr /v "resources:" | findstr /v "reservations:" | findstr /v "devices:" | findstr /v "driver:" | findstr /v "count:" | findstr /v "capabilities:" | findstr /v "- gpu" > docker-compose.local-ollama.temp
move /y docker-compose.local-ollama.temp docker-compose.local-ollama.yaml >nul

echo %WHITE%Starting Open WebUI with local Ollama...%NC%
REM Set Node.js memory limit for the build
set NODE_OPTIONS=--max-old-space-size=8192

REM Run docker-compose with our custom configuration
docker compose -f docker-compose.local-ollama.yaml up -d --build

if errorlevel 1 (
    echo %RED%There was an error starting Open WebUI.%NC%
) else (
    echo %GREEN%Open WebUI started successfully.%NC%
    echo You can access it at http://localhost:3000
)

endlocal
