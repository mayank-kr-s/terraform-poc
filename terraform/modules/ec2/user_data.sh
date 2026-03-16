#!/bin/bash
# ─────────────────────────────────────────────
# EC2 User Data Script — Runs on first boot
# ─────────────────────────────────────────────
set -euo pipefail

echo ">>> Starting user data script..."

# Update system packages
yum update -y

# Install Nginx
yum install -y nginx

# Get instance metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a simple web page
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>${project} - ${environment}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .card { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); max-width: 600px; }
        h1 { color: #232f3e; }
        .info { color: #666; }
        .highlight { color: #ff9900; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Hello from AWS! 🚀</h1>
        <p class="info">Environment: <span class="highlight">${environment}</span></p>
        <p class="info">Instance ID: <span class="highlight">$INSTANCE_ID</span></p>
        <p class="info">Private IP: <span class="highlight">$PRIVATE_IP</span></p>
        <p class="info">Availability Zone: <span class="highlight">$AZ</span></p>
        <p class="info">Project: <span class="highlight">${project}</span></p>
        <hr>
        <p><small>Deployed with Terraform + Ansible | Served by Nginx</small></p>
    </div>
</body>
</html>
EOF

# Create health check endpoint
mkdir -p /usr/share/nginx/html
cat > /usr/share/nginx/html/health <<EOF
healthy
EOF

# Configure Nginx
cat > /etc/nginx/conf.d/default.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
NGINX

# Remove default nginx server block if exists
rm -f /etc/nginx/conf.d/nginx.conf.default 2>/dev/null || true

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

echo ">>> User data script complete!"
