Write-Host "Setting Flutter China mirrors..." -ForegroundColor Green
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:ANDROID_HOME = "D:\Android\Sdk"
$env:Path = "$env:Path;E:\flutter\bin;D:\Android\Sdk\build-tools\35.0.0;D:\Android\Sdk\platform-tools"

Write-Host ""
Write-Host "Starting Flutter app..." -ForegroundColor Green
Set-Location "E:\yimaflutter"
flutter run
