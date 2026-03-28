@echo off
echo ===== FIXING FLUTTER PROJECT =====

echo.
echo [1/5] Adding web support...
call flutter create . --platforms=web

echo.
echo [2/5] Creating l10n output directory...
if not exist "lib\l10n\generated" mkdir lib\l10n\generated

echo.
echo [3/5] Fixing l10n imports in all Dart files...
powershell -Command "Get-ChildItem -Path lib -Recurse -Filter *.dart | ForEach-Object { (Get-Content $_.FullName) -replace \"import 'package:flutter_gen/gen_l10n/app_localizations.dart'\", \"import 'package:autobazar/l10n/generated/app_localizations.dart'\" | Set-Content $_.FullName }"

echo.
echo [4/5] Running flutter gen-l10n...
call flutter gen-l10n

echo.
echo [5/5] Getting packages...
call flutter pub get

echo.
echo ===== ALL FIXES APPLIED =====
echo Now run: flutter run -d chrome --dart-define=BASE_URL=http://localhost:8000
