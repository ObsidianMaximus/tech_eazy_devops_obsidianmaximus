#!/bin/bash

set -e

sudo apt update -y
sudo apt install maven openjdk-21-jdk git unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

S3_BUCKET="${s3_bucket_name}"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="/tmp/ec2-logs-$${TIMESTAMP}"


# Create shutdown script
cat <<EOF > /opt/upload-logs.sh
#!/bin/bash

# Exit on any error
set -e

TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)

# Use /var/tmp instead of /tmp as it's less likely to be read-only during shutdown
LOG_DIR="/var/tmp/ec2-logs-\$${TIMESTAMP}"
ARCHIVE_PATH="/var/tmp/ec2-logs-\$${TIMESTAMP}.tar.gz"

# Create directory
mkdir -p "\$${LOG_DIR}"

# List of logs to archive (with error handling)
echo "Collecting log files..."
cp /var/log/cloud-init.log "\$${LOG_DIR}/" 2>/dev/null || echo "Warning: cloud-init.log not found"
cp /var/log/cloud-init-output.log "\$${LOG_DIR}/" 2>/dev/null || echo "Warning: cloud-init-output.log not found"
cp /var/log/syslog "\$${LOG_DIR}/" 2>/dev/null || echo "Warning: syslog not found"

# Check if any files were copied
if [ ! "\$(ls -A \$${LOG_DIR})" ]; then
    echo "Error: No log files found to archive"
    exit 1
fi

# Compress logs
echo "Compressing logs..."
tar -czf "\$${ARCHIVE_PATH}" -C /var/tmp "\$(basename \$${LOG_DIR})"

# Verify archive was created
if [ ! -f "\$${ARCHIVE_PATH}" ]; then
    echo "Error: Failed to create archive"
    exit 1
fi

# Upload to S3
echo "Uploading to S3..."
aws s3 cp "\$${ARCHIVE_PATH}" "s3://${s3_bucket_name}/ec2-logs/log-\$${TIMESTAMP}.tar.gz" || {
    echo "S3 upload failed. Checking AWS configuration..."
    echo "AWS CLI version: \$(aws --version)"
    echo "Current AWS identity:"
    aws sts get-caller-identity || echo "Failed to get AWS identity"
    echo "Checking S3 bucket access:"
    aws s3 ls s3://${s3_bucket_name}/ --max-items 1 || echo "Failed to list S3 bucket"
    exit 1
}

# Clean up
rm -rf "\$${LOG_DIR}" "\$${ARCHIVE_PATH}"

echo "Log upload completed successfully"
EOF

chmod +x /opt/upload-logs.sh

# Register script to run on shutdown
echo "[Unit]
Description=Upload EC2 logs to S3 before shutdown
DefaultDependencies=no
After=network.target
Before=shutdown.target reboot.target halt.target
Conflicts=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/upload-logs.sh
TimeoutStartSec=300
RemainAfterExit=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/upload-logs.service

# Enable the service
systemctl enable upload-logs.service