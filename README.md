# Purnata Enterprise Contractor Manager

A lightweight Flutter app for Android and iOS to manage project expenses offline.

## Included in version 1
- Multiple construction projects
- Contract amount and project-wise running total
- Labor payment calculation: days × daily rate + overtime/extra − deduction
- Material purchases: Bricks, Stone, Sand, Bitumen, Diesel, Rod, Cement, Other
- Material calculation: quantity × unit price + transport/extra
- Daily costs and other costs
- Project report with total cost and remaining/estimated margin
- Offline local storage on the phone
- No login, cloud account, ads, or internet requirement

## First-time setup
This package contains the app source. Flutter generates the Android/iOS platform wrapper for your computer.

1. Install Flutter SDK and Android Studio.
2. Open a terminal inside this folder.
3. Run:

   flutter create . --platforms=android,ios --org com.purnata --project-name purnata_enterprise
   flutter pub get
   flutter run

## Android APK
With a phone connected or emulator configured:

   flutter build apk --release

APK will be under:
`build/app/outputs/flutter-apk/app-release.apk`

## iPhone / iOS
Apple requires macOS + Xcode for iOS compilation and signing.
On a Mac:

   flutter create . --platforms=ios --org com.purnata --project-name purnata_enterprise
   flutter pub get
   open ios/Runner.xcworkspace

Choose your Apple signing team in Xcode and run on the iPhone.

## Data note
Version 1 stores records locally using shared_preferences as JSON. This is simple and lightweight. For larger long-term accounting data, a later version should move to SQLite/Drift and add encrypted backup/export.
