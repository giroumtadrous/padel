#!/bin/sh
set -e

cd "$CI_PRIMARY_REPOSITORY_PATH"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

flutter config --no-enable-swift-package-manager
flutter doctor
flutter pub get
flutter precache --ios

cd ios

gem install xcodeproj

ruby -e '
require "xcodeproj"

project_path = "Runner.xcodeproj"
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == "Runner" }
group = project.main_group.find_subpath("Runner", true)

file_name = "SceneDelegate.swift"
existing = target.source_build_phase.files_references.any? { |f| f.path == file_name }

unless existing
  file_ref = group.new_reference(file_name)
  target.add_file_references([file_ref])
  project.save
  puts "Added #{file_name} to Runner target"
else
  puts "#{file_name} already in Runner target"
end
'

pod install