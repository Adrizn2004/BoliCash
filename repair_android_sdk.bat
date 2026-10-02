@echo off
setlocal
set ANDROID_SDK_ROOT=C:\Users\Adrian Vasquez\AppData\Local\Android\Sdk
set ANDROID_HOME=C:\Users\Adrian Vasquez\AppData\Local\Android\Sdk
set JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot
set PATH=%JAVA_HOME%\bin;%PATH%
cd /d C:\app bancaria

if not exist "%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" (
  echo sdkmanager.bat no encontrado en %ANDROID_SDK_ROOT%
  exit /b 1
)

echo Aceptando licencias de Android SDK...
(
  for /L %i in (1,1,30) do @echo y
) | "%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_SDK_ROOT%" --licenses

echo Instalando plataforma, build-tools y NDK requerido...
"%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%ANDROID_SDK_ROOT%" --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;28.2.13676358"

echo Configurando Flutter con el SDK correcto...
flutter config --android-sdk "%ANDROID_SDK_ROOT%"

echo Compilando APK debug...
flutter build apk --debug
