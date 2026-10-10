@echo off
setlocal EnableExtensions
cd /d "%~dp0"

where git >nul 2>nul || (
  echo Git is not installed. Install Git for Windows from https://git-scm.com/download/win and rerun this file.
  pause
  exit /b 1
)

set "REPO_URL=https://github.com/alitanhaii1970-commits/Alone-vpn.git"
set "WORKDIR=%TEMP%\alone-vpn-github-upload"

if exist "%WORKDIR%" rmdir /s /q "%WORKDIR%"
echo Cloning the ALONE VPN repository into a temporary folder...
git clone "%REPO_URL%" "%WORKDIR%"
if errorlevel 1 (
  echo Clone failed. Check the repository URL and your network connection.
  echo If Git requests login, use Git Credential Manager/browser sign-in; do not paste a token into this script.
  pause
  exit /b 1
)

for %%D in ("%WORKDIR%\*") do if exist "%%~fD" if /I not "%%~nxD"==".git" rmdir /s /q "%%~fD" 2>nul
for %%F in ("%WORKDIR%\*.*") do if exist "%%~fF" del /q "%%~fF" 2>nul

robocopy "%~dp0" "%WORKDIR%" /E /XD .git build .dart_tool .idea .vscode /XF *.pyc /NFL /NDL /NJH /NJS /NC /NS
if errorlevel 8 (
  echo Failed to copy project files.
  pause
  exit /b 1
)

pushd "%WORKDIR%"
git add -A
git diff --cached --quiet
if not errorlevel 1 (
  echo No changes to push; the repository already matches this project.
  popd
  pause
  exit /b 0
)
git commit -m "Add ALONE VPN Flutter Android project and APK build workflow"
if errorlevel 1 (
  echo Commit failed. Verify your Git user.name and user.email settings.
  popd
  pause
  exit /b 1
)
git push origin HEAD:main
if errorlevel 1 (
  echo Push failed. Use Git Credential Manager/browser authentication; never paste a PAT into chat.
  popd
  pause
  exit /b 1
)
popd
echo.
echo Source pushed. Open https://github.com/alitanhaii1970-commits/Alone-vpn/actions to monitor APK build.
echo The installable APK appears under the workflow run's Artifacts once the build succeeds.
pause
