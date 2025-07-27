#!/bin/bash
set -e

# Enable verbose output
set -x

# Variables
REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"
LOG_DIR="/tmp/app-logs"

echo "=== DEPLOY SCRIPT STARTED at $(date) ==="

# S3_BUCKET_NAME should be passed as environment variable from GitHub Actions
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "Error: S3_BUCKET_NAME environment variable is not set"
    echo "This script should be called from GitHub Actions with the S3 bucket name"
    exit 1
fi

echo "Using S3 bucket: $S3_BUCKET_NAME"

# Clean up previous clone if it exists
rm -rf "$APP_DIR"

# Clone the repository
git clone "$REPO_URL" "$APP_DIR"

# Build the project
cd "$APP_DIR"
mvn clean package

# Create log directory
mkdir -p "$LOG_DIR"

# Run the Java application in the background
# The 'nohup' and '&' ensure the app keeps running after the script finishes
echo "Starting Java application..."
sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar > "$LOG_DIR/app.log" 2>&1 &
APP_PID=$!

echo "Application started with PID: $APP_PID"

# Wait a few seconds for the app to generate some logs
sleep 10

# Function to upload logs to S3
upload_logs() {
    local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local log_archive="/tmp/app-logs-${timestamp}.tar.gz"
    
    echo "Collecting application logs..."
    
    # Copy current logs
    cp "$LOG_DIR/app.log" "$LOG_DIR/app-${timestamp}.log" 2>/dev/null || echo "Warning: app.log not found"
    
    # Add Maven build logs if they exist
    if [ -f "$APP_DIR/target/maven-build.log" ]; then
        cp "$APP_DIR/target/maven-build.log" "$LOG_DIR/maven-build-${timestamp}.log"
    fi
    
    # Create archive
    tar -czf "$log_archive" -C /tmp "$(basename $LOG_DIR)"
    
    # Upload to S3
    echo "Uploading logs to S3..."
    aws s3 cp "$log_archive" "s3://${S3_BUCKET_NAME}/app/logs/app-logs-${timestamp}.tar.gz"
    
    if [ $? -eq 0 ]; then
        echo "Successfully uploaded logs to s3://${S3_BUCKET_NAME}/app/logs/app-logs-${timestamp}.tar.gz"
    else
        echo "Failed to upload logs to S3"
    fi
    
    # Clean up
    rm -f "$log_archive"
}

# Upload initial logs
upload_logs

echo "Deployment script finished. Application is running with PID: $APP_PID"
echo "Logs are being captured in: $LOG_DIR/app.log"
echo "Application logs have been uploaded to S3 bucket: $S3_BUCKET_NAME/app/logs/"
echo "=== DEPLOY SCRIPT COMPLETED at $(date) ==="