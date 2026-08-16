#!/bin/sh
set -e

# Xcode Cloud clones your repo to $CI_WORKSPACE
cd $CI_WORKSPACE/repository

# Install Flutter (adjust the branch/version to match what your app uses)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter doctor
flutter pub get

# Generate the iOS build files Flutter normally creates via `flutter build`
cd ios
pod install