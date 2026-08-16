#!/bin/sh
set -e

cd $CI_WORKSPACE

# Install Flutter (adjust the branch/version to match what your app uses)
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter doctor
flutter pub get

cd ios
pod install