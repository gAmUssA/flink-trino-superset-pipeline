#!/bin/bash

# 🚀 Initialize Gradle Wrapper for the project
# This script uses SDKMAN to ensure Gradle is available

# Check if SDKMAN is installed
if [ ! -d "$HOME/.sdkman" ]; then
    echo "🔍 SDKMAN not found. Installing SDKMAN..."
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
else
    echo "✅ SDKMAN already installed"
    source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# Install Gradle if not already installed
if ! sdk list gradle | grep -q "installed"; then
    echo "🔍 Gradle not found. Installing Gradle..."
    sdk install gradle
else
    echo "✅ Gradle already installed"
fi

# Initialize Gradle wrapper
echo "🚀 Initializing Gradle wrapper..."
gradle wrapper

echo "✅ Gradle wrapper initialized successfully!"
echo "🔧 You can now build the project using: ./gradlew build"
