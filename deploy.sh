#!/bin/bash
set -e

# Variables
REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"

# Clean up previous clone if exists
rm -rf "$APP_DIR"

# Clone the repository
git clone "$REPO_URL" "$APP_DIR"

# Build the project
cd "$APP_DIR"
mvn clean package

# Run the Java application
sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar > app.log 2>&1 &

# Wait for app to start
sleep 20

# Test if app is reachable via port 80
if curl -s --connect-timeout 10 http://localhost:80/ > /dev/null; then
  echo "App is reachable on port 80"
else
  echo "App is NOT reachable on port 80"
  exit 1
fi