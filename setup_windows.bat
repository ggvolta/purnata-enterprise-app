@echo off
flutter create . --platforms=android,ios --org com.purnata --project-name purnata_enterprise
if errorlevel 1 pause & exit /b 1
flutter pub get
if errorlevel 1 pause & exit /b 1
echo.
echo Purnata Enterprise project is ready.
echo Connect an Android phone with USB debugging and run: flutter run
pause
