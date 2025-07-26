#!/bin/bash
set -e

# Variables
REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"

# Clean up previous clone if it exists
rm -rf "$APP_DIR"

# Clone the repository
git clone "$REPO_URL" "$APP_DIR"

# Build the project
cd "$APP_DIR"
mvn clean package

# Run the Java application in the background
# The 'nohup' and '&' ensure the app keeps running after the script finishes
sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

echo "Deployment script finished. Application is starting."