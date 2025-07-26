#!/bin/bash
set -ex

# Install base packages plus the AWS CLI
sudo apt-get update -y
sudo apt-get install -y maven openjdk-21-jdk git unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# --- Create the shutdown script ---
# This script will be responsible for uploading system logs to S3.
# We use a "here document" (tee <<'EOF') to write the multi-line script to a file.
sudo tee /usr/local/bin/shutdown_logs.sh > /dev/null <<'EOF'
#!/bin/bash
# Requirement 4: Upload EC2 logs to the S3 bucket after instance shutdown

# The S3 bucket name will be passed via an environment file created by the main instance resource.
# This is a simple way to pass variables from Terraform to the instance.
if [ -f /etc/techeazy_env ]; then
    . /etc/techeazy_env
fi

# If the bucket name isn't set, exit to prevent errors.
if [ -z "$S3_BUCKET_NAME" ]; then
    echo "S3_BUCKET_NAME not set, cannot upload logs." >> /tmp/shutdown_error.log
    exit 1
fi

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="s3://${S3_BUCKET_NAME}/ec2-system-logs/$TIMESTAMP"

echo "Uploading system logs to $LOG_DIR" >> /tmp/shutdown.log

# Upload the cloud-init log and syslog to the specified S3 path.
# The EC2 instance has permission to do this via the IAM role attached to it.
aws s3 cp /var/log/cloud-init.log "$LOG_DIR/cloud-init.log" >> /tmp/shutdown.log 2>&1
aws s3 cp /var/log/syslog "$LOG_DIR/syslog" >> /tmp/shutdown.log 2>&1

echo "Log upload complete." >> /tmp/shutdown.log
EOF

# Make the shutdown script executable
sudo chmod +x /usr/local/bin/shutdown_logs.sh

# --- Create the systemd service to run the script on shutdown ---
# systemd is the standard service manager on modern Linux distributions.
# This service is configured to run before the system halts or reboots.
sudo tee /etc/systemd/system/upload-logs.service > /dev/null <<'EOF'
[Unit]
Description=Upload system logs to S3 on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/shutdown_logs.sh
RemainAfterExit=true

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

# Enable the service so it starts automatically on boot and is ready for shutdown.
sudo systemctl enable upload-logs.service

echo "S3_BUCKET_NAME=${S3_BUCKET_NAME}" | sudo tee /etc/techeazy_env > /dev/null