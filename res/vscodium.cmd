@echo off
setlocal

set VSCODE_APPDATA=%~dp0data\appdata
set VSCODE_LOGS=%~dp0data\logs
set VSCODE_EXTENSIONS=%~dp0data\extensions

set VSCODE_DEV=
set ELECTRON_RUN_AS_NODE=1

if not exist "%~dp0app\resources\app\out\cli.js" (
  echo [ERROR] VSCodium CLI entry point not found: "%~dp0app\resources\app\out\cli.js"
  echo Make sure the portable app has been unpacked correctly.
  exit /b 1
)

call "%~dp0app\VSCodium.exe" "%~dp0app\resources\app\out\cli.js" %*
set exit_code=%errorlevel%
endlocal & exit /b %exit_code%
