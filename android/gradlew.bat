@ECHO OFF
SETLOCAL
SET APP_HOME=%~dp0
SET GRADLE_VERSION=8.10.2
IF DEFINED GRADLE_USER_HOME (
  SET GRADLE_BASE=%GRADLE_USER_HOME%
) ELSE (
  SET GRADLE_BASE=%USERPROFILE%\.gradle
)
SET GRADLE_HOME_DIR=%GRADLE_BASE%\manual-wrapper\gradle-%GRADLE_VERSION%
SET GRADLE_BIN=%GRADLE_HOME_DIR%\bin\gradle.bat

IF NOT EXIST "%GRADLE_BIN%" (
  IF NOT EXIST "%GRADLE_BASE%\manual-wrapper" MKDIR "%GRADLE_BASE%\manual-wrapper"
  SET ARCHIVE=%TEMP%\gradle-%GRADLE_VERSION%-bin.zip
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip' -OutFile '%ARCHIVE%'; Expand-Archive -Force '%ARCHIVE%' '%GRADLE_BASE%\manual-wrapper'"
  IF ERRORLEVEL 1 EXIT /B 1
)

CALL "%GRADLE_BIN%" -p "%APP_HOME%" %*
ENDLOCAL
