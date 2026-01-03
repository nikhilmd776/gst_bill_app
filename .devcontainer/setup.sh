#!/bin/bash

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc

# Install Android SDK
mkdir -p $HOME/android-sdk/cmdline-tools
cd $HOME/android-sdk/cmdline-tools
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest

# Set environment variables
export ANDROID_HOME=$HOME/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
echo 'export ANDROID_HOME=$HOME/android-sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc

# Accept licenses and install components
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "platforms;android-35" "build-tools;35.0.0"

# Configure Gradle
echo 'org.gradle.daemon=false' > android/gradle.properties
echo 'android.useAndroidX=true' >> android/gradle.properties
echo 'android.enableJetifier=true' >> android/gradle.properties

# Source bashrc
source ~/.bashrc

# Verify
flutter --version
flutter doctor