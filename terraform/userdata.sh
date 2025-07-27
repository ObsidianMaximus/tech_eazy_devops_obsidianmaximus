#!/bin/bash

set -e

sudo apt update -y
sudo apt install maven openjdk-21-jdk git -y

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

S3_BUCKET="${s3_bucket_name}"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOG_DIR="/tmp/ec2-logs-${TIMESTAMP}"


# Create shutdown script
cat <<EOF > /opt/upload-logs.sh
#!/bin/bash

mkdir -p \${LOG_DIR}

# List of logs to archive
cp /var/log/cloud-init.log \${LOG_DIR}/ || true
cp /var/log/cloud-init-output.log \${LOG_DIR}/ || true
cp /var/log/syslog \${LOG_DIR}/ || true
# Add more logs here if needed

# Compress logs
tar -czf \${LOG_DIR}.tar.gz -C /tmp \$(basename \${LOG_DIR})

# Upload to S3
aws s3 cp \${LOG_DIR}.tar.gz s3://${s3_bucket_name}/ec2-logs/log-\${TIMESTAMP}.tar.gz
EOF

chmod +x /opt/upload-logs.sh

# Register script to run on shutdown
echo "[Unit]
Description=Upload EC2 logs to S3 before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/upload-logs.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/upload-logs.service

# Enable the service
systemctl enable upload-logs.service