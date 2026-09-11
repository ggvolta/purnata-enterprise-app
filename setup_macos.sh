#!/bin/bash
set -e
flutter create . --platforms=android,ios --org com.purnata --project-name purnata_enterprise
flutter pub get
echo "Purnata Enterprise project is ready. Run: flutter run"
