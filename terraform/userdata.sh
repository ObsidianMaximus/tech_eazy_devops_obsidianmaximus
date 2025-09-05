#!/bin/bash

set -e

sudo apt update -y
sudo apt install maven openjdk-21-jdk git unzip -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Setup CloudWatch agent
echo "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
sudo systemctl enable amazon-cloudwatch-agent

echo "Writing CloudWatch agent config..."
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

# Create optimized CloudWatch config inline for faster streaming
cat << 'EOF' | sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/tmp/app-logs/app.log",
                        "log_group_name": "techeazy-app-logs",
                        "log_stream_name": "{instance_id}/app.log",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    },
                    {
                        "file_path": "/var/log/cloud-init-output.log",
                        "log_group_name": "techeazy-system-logs",
                        "log_stream_name": "{instance_id}/cloud-init-output.log",
                        "timestamp_format": "%Y-%m-%d %H:%M:%S"
                    }
                ]
            }
        },
        "log_stream_name": "{instance_id}",
        "force_flush_interval": 5
    },
    "metrics": {
        "append_dimensions": {
            "InstanceId": "$${aws:InstanceId}"
        },
        "metrics_collected": {
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 30
            },
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 30,
                "totalcpu": true
            }
        }
    }
}
EOF

echo "Starting CloudWatch agent..."
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Create app log directory early
sudo mkdir -p /tmp/app-logs
sudo chmod 755 /tmp/app-logs

# Set the S3 log path from Terraform variable - expand variables immediately
S3_BUCKET_NAME="${s3_bucket_name}"
STAGE="${stage}"
S3_LOG_PATH="s3://${s3_bucket_name}/logs/${stage}"
echo "S3_LOG_PATH=$S3_LOG_PATH" >> /etc/environment

# Create shutdown script
cat <<EOF > /opt/upload-logs.sh
#!/bin/bash

# Exit on any error
set -e

# Source environment variables
source /etc/environment

TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="/var/tmp/ec2-logs-\$${TIMESTAMP}"
ARCHIVE_PATH="/var/tmp/ec2-logs-\$${TIMESTAMP}.tar.gz"

# Check if S3_LOG_PATH is set
if [ -z "\$S3_LOG_PATH" ]; then
    echo "Error: S3_LOG_PATH not set"
    exit 1
fi

echo "Using S3 log path: \$S3_LOG_PATH"

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

# Upload to S3 using stage-specific path
echo "Uploading to S3..."
aws s3 cp "\$${ARCHIVE_PATH}" "\$S3_LOG_PATH/ec2-logs/log-\$${TIMESTAMP}.tar.gz" || {
    echo "S3 upload failed. Checking AWS configuration..."
    echo "AWS CLI version: \$(aws --version)"
    echo "Current AWS identity:"
    aws sts get-caller-identity || echo "Failed to get AWS identity"
    echo "Checking S3 bucket access:"
    aws s3 ls "\$S3_LOG_PATH" || echo "Failed to list S3 path"
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