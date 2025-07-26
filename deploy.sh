#!/bin/bash
set -ex

# --- Variables and Input Validation ---

# The script now accepts two arguments:
# $1: The deployment stage (e.g., "dev" or "prod")
# $2: The S3 bucket name for uploading logs
STAGE=$1
S3_BUCKET_NAME=$2

REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"

# Validate that both required arguments were provided.
if [ -z "$STAGE" ] || [ -z "$S3_BUCKET_NAME" ]; then
  echo "Error: Stage and S3 Bucket Name must be provided."
  echo "Usage: $0 <stage> <s3_bucket_name>"
  exit 1
fi

# --- Deployment Steps ---

# Clean up previous deployment artifacts
sudo rm -rf "$APP_DIR"

# Clone the application repository
git clone "$REPO_URL" "$APP_DIR"

# Navigate into the application directory and build the project
cd "$APP_DIR"
sudo mvn clean package

# Run the Java application in the background with the correct Spring profile.
# Redirect its output to /tmp/app.log
echo "--- Starting the Java application for stage: $STAGE ---"
sudo nohup java -jar -Dspring.profiles.active=$STAGE target/hellomvc-0.0.1-SNAPSHOT.jar > /tmp/app.log 2>&1 &

echo "Deployment script finished. Waiting for app to start and log to be created..."
sleep 60 # Give the app a moment to start up and generate the log file.

# --- Log Upload ---

# Requirement 5: Upload logs of app deployed to bucket /app/logs
echo "--- Uploading application log to S3 ---"
# The EC2 instance has permission to run this command via its attached IAM role.
# We create a unique name for the log file using the stage and current timestamp.
aws s3 cp /tmp/app.log "s3://${S3_BUCKET_NAME}/app-logs/app-log-${STAGE}-$(date +%s).log"

echo "--- Application log uploaded successfully. ---"