# -----------------------------------------------------------------------------
# FILE: deploy.sh (Updated with Better Logging)
#
# This version adds comprehensive logging to capture every command and its
# output, making it much easier to debug failures on the EC2 instance.
# -----------------------------------------------------------------------------

#!/bin/bash
# -e: exit immediately if a command exits with a non-zero status.
# -x: print each command to stderr before executing it.
set -ex

# --- Variables and Input Validation ---
STAGE=$1
S3_BUCKET_NAME=$2
REPO_URL="https://github.com/ObsidianMaximus/tech_eazy_devops_obsidianmaximus.git"
APP_DIR="/tmp/app"
LOG_FILE="/tmp/deploy_output.log"

# Clean up old log file to ensure we only see output from this run
sudo rm -f $LOG_FILE

# Redirect all subsequent output (stdout and stderr) to the log file AND the console
exec > >(sudo tee -a $LOG_FILE) 2>&1

echo "--- Starting Deployment: $(date) ---"
echo "Stage: $STAGE, Bucket: $S3_BUCKET_NAME"

if [ -z "$STAGE" ] || [ -z "$S3_BUCKET_NAME" ]; then
  echo "Error: Stage and S3 Bucket Name must be provided."
  exit 1
fi

# --- Deployment Steps ---
sudo rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"
sudo mvn clean package

# --- Application Start ---
echo "--- Starting Java application ---"
sudo nohup java -jar -Dspring.profiles.active=$STAGE target/hellomvc-0.0.1-SNAPSHOT.jar > /tmp/app.log 2>&1 &
sleep 20

# --- Log Upload ---
echo "--- Uploading application log to S3 ---"
aws s3 cp /tmp/app.log "s3://${S3_BUCKET_NAME}/app-logs/app-log-${STAGE}-$(date +%s).log"
echo "--- Deployment script finished successfully. ---"
