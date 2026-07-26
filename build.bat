@echo off
setlocal enabledelayedexpansion
title Suno Android - Build

cd /d "%~dp0"

echo ============================================
echo  Suno Player for Android - Builder
echo ============================================
echo.

:: --- 1. Check Java ------------------------------------------------
echo [1/5] Checking Java...
where java >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo Java 17+ not found.
    echo.
    echo Visit https://adoptium.net and install Temurin 17 (LTS).
    echo Or run: winget install EclipseAdoptium.Temurin.17.JDK
    echo.
    echo After installing, re-run build.bat
    pause & exit /b 1
)

java -version 2>&1 | findstr "17" >nul
if %ERRORLEVEL% neq 0 (
    echo Java found but may not be version 17.
    echo Attempting to continue...
) else (
    echo Java 17 OK
)

:: --- 2. Gradle wrapper --------------------------------------------
echo [2/5] Setting up Gradle...

:: --- 3. Android SDK ------------------------------------------------
echo [3/5] Setting up Android SDK...

set "ANDROID_SDK_ROOT=%USERPROFILE%\Android\Sdk"
set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
set "CMDLINE_TOOLS=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin"

if exist "%CMDLINE_TOOLS%\sdkmanager.bat" (
    echo Android SDK found
) else (
    echo Downloading Android command-line tools...
    mkdir "%ANDROID_SDK_ROOT%" 2>nul
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -OutFile '%TEMP%\cmdline-tools.zip' -UseBasicParsing" <nul
    
    if not exist "%TEMP%\cmdline-tools.zip" (
        echo Download failed. Trying alternative URL...
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip' -TimeoutSec 60 -OutFile '%TEMP%\cmdline-tools.zip' -UseBasicParsing" <nul
    )
    
    if not exist "%TEMP%\cmdline-tools.zip" (
        echo [ERROR] Cannot download Android SDK tools.
        echo Download manually from:
        echo https://developer.android.com/studio#command-line-tools-only
        echo Extract to: %ANDROID_SDK_ROOT%\cmdline-tools\latest\
        pause & exit /b 1
    )
    
    powershell -Command "Expand-Archive -Path '%TEMP%\cmdline-tools.zip' -DestinationPath '%TEMP%\cmdline-tools-tmp' -Force" <nul
    
    if exist "%TEMP%\cmdline-tools-tmp\cmdline-tools\" (
        move /y "%TEMP%\cmdline-tools-tmp\cmdline-tools" "%ANDROID_SDK_ROOT%\cmdline-tools\latest" >nul 2>&1
    ) else (
        mkdir "%ANDROID_SDK_ROOT%\cmdline-tools\latest" 2>nul
        xcopy /E /I /Y "%TEMP%\cmdline-tools-tmp" "%ANDROID_SDK_ROOT%\cmdline-tools\latest" >nul
    )
    
    if not exist "%CMDLINE_TOOLS%\sdkmanager.bat" (
        echo [ERROR] SDK manager not found after extraction.
        pause & exit /b 1
    )
    
    echo.
    echo [IMPORTANT] Accept Android SDK license:
    echo.
    call "%CMDLINE_TOOLS%\sdkmanager.bat" --sdk_root="%ANDROID_SDK_ROOT%" --licenses
    echo.
    echo If the license prompt above failed, run manually:
    echo   sdkmanager --licenses
    echo.
    echo Installing SDK...
    call "%CMDLINE_TOOLS%\sdkmanager.bat" --sdk_root="%ANDROID_SDK_ROOT%" "platforms;android-35" "build-tools;35.0.0"
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] SDK install failed.
        pause & exit /b 1
    )
)

:: --- 4. Build -------------------------------------------------------
echo [4/5] Building APK...
echo.

if not exist "gradlew.bat" (
    echo Generating Gradle wrapper...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/gradle/gradle/v8.10.2/gradlew.bat' -OutFile 'gradlew.bat' -UseBasicParsing" <nul
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/gradle/gradle/v8.10.2/gradlew' -OutFile 'gradlew' -UseBasicParsing" <nul
)

echo Building release APK...
call gradlew assembleRelease 2>&1

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build failed.
    echo Trying debug build...
    call gradlew assembleDebug 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Debug build also failed.
        pause & exit /b 1
    )
)

:: --- 5. Result ------------------------------------------------------
echo [5/5] APK generated.
echo.
for /r "app\build\outputs\apk" %%f in (*.apk) do (
    echo APK: %%f
)

echo.
echo ============================================
echo  Build complete!
echo  APK is in: app\build\outputs\apk
echo ============================================
echo.
echo  To install on your Android:
echo   1. Enable 'Unknown sources' on your phone
echo   2. Copy the APK via Dropbox, USB, or cloud
echo   3. Open it on your phone and install
echo   4. Open the app and sign in to Suno
echo.
echo  Alternative (phone connected via USB):
echo    gradlew installDebug
echo.
pause

