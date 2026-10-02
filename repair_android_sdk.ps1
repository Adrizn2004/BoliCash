$ErrorActionPreference = 'Stop'

$sdk = 'C:\Users\Adrian Vasquez\AppData\Local\Android\Sdk'
$java = 'C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot'

$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_HOME = $sdk
$env:JAVA_HOME = $java
$env:Path = "$java\bin;" + $env:Path

Write-Host "SDK root: $sdk"
Write-Host "JAVA_HOME: $java"

if (!(Test-Path "$sdk\cmdline-tools\latest\bin\sdkmanager.bat")) {
    throw "sdkmanager.bat no encontrado en $sdk"
}

Write-Host "Aceptando licencias de Android SDK..."
1..30 | ForEach-Object { 'y' } | & "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$sdk" --licenses

Write-Host "Instalando plataforma, build-tools y NDK requerido..."
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$sdk" --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;28.2.13676358"

Write-Host "Configurando Flutter con el SDK correcto..."
flutter config --android-sdk "$sdk"

Write-Host "Compilando APK debug..."
flutter build apk --debug
