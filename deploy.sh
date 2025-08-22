#!/bin/bash
set -e

# Enable verbose output
set -x

# Get stage parameter (default to dev)
STAGE=${1:-dev}

# Validate stage
if [[ "$STAGE" != "dev" && "$STAGE" != "prod" ]]; then
    echo "Error: Stage must be 'dev' or 'prod'"
    exit 1
fi

echo "=== DEPLOY SCRIPT STARTED for stage: $STAGE at $(date) ==="

# Fetch configuration based on stage
if [ "$STAGE" = "dev" ]; then
    echo "Using dev configuration..."
    if [ ! -f "config/dev.json" ]; then
        echo "Error: config/dev.json not found"
        exit 1
    fi
    S3_LOG_PATH=$(jq -r '.s3_log_path' "config/dev.json")
elif [ "$STAGE" = "prod" ]; then
    echo "Fetching prod configuration..."
    if [ -n "$GITHUB_TOKEN" ]; then
        curl -H "Authorization: token $GITHUB_TOKEN" \
             -H "Accept: application/vnd.github.v3.raw" \
             -o temp-prod-config.json \
             "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/config/prod.json"
        S3_LOG_PATH=$(jq -r '.s3_log_path' "temp-prod-config.json")
        rm -f temp-prod-config.json
    else
        echo "Warning: GITHUB_TOKEN not set, using local prod config"
        if [ ! -f "config/prod.json" ]; then
            echo "Error: config/prod.json not found"
            exit 1
        fi
        S3_LOG_PATH=$(jq -r '.s3_log_path' "config/prod.json")
    fi
fi

# Extract bucket name from S3 path for backward compatibility
S3_BUCKET_NAME=$(echo "$S3_LOG_PATH" | sed 's|s3://||' | cut -d'/' -f1)
export S3_BUCKET_NAME
export S3_LOG_PATH

echo "Using S3 log path: $S3_LOG_PATH"
echo "Using S3 bucket: $S3_BUCKET_NAME"

# Variables
REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"
LOG_DIR="/tmp/app-logs"

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
sleep 5

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
    
    # Upload to S3 using the stage-specific path
    echo "Uploading logs to S3..."
    aws s3 cp "$log_archive" "${S3_LOG_PATH}app-logs-${timestamp}.tar.gz"
    
    if [ $? -eq 0 ]; then
        echo "Successfully uploaded logs to ${S3_LOG_PATH}app-logs-${timestamp}.tar.gz"
    else
        echo "Failed to upload logs to S3"
    fi
    
    # Clean up
    rm -f "$log_archive"
}

# Upload initial logs
upload_logs

echo "Deployment script finished for stage: $STAGE. Application is running with PID: $APP_PID"
echo "Logs are being captured in: $LOG_DIR/app.log"
echo "Application logs have been uploaded to S3 path: $S3_LOG_PATH"
echo "=== DEPLOY SCRIPT COMPLETED at $(date) ==="