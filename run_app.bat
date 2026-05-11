@echo off
echo Setting Flutter China mirrors...
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
echo.
echo Starting Flutter app...
cd /d E:\yimaflutter
flutter run
pause
