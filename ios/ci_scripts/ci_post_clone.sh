#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Install Flutter (adjust the branch/version to match what your app uses)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter doctor
flutter pub get
flutter precache --ios

cd ios
pod install