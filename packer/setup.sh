#!/usr/bin/env bash
# Provisions the ReportMate self-host stack into the appliance image:
# installs Docker, stages the compose project, and enables a boot-time service
# that brings the stack up. First boot generates secrets if none were supplied.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo mkdir -p /opt/reportmate
sudo cp -r /tmp/reportmate/. /opt/reportmate/
sudo rm -rf /opt/reportmate/packer

sudo tee /opt/reportmate/first-boot.sh > /dev/null <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/reportmate
if [ ! -f .env ]; then
  cp .env.example .env
  gen() { openssl rand -hex 24; }
  sed -i "s|change-me-strong-db-password|$(gen)|" .env
  sed -i "s|change-me-to-a-long-random-string|$(gen)|g" .env
fi
exec docker compose up
EOS
sudo chmod +x /opt/reportmate/first-boot.sh

sudo tee /etc/systemd/system/reportmate.service > /dev/null <<'EOS'
[Unit]
Description=ReportMate self-host stack
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/reportmate
ExecStart=/opt/reportmate/first-boot.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOS

sudo systemctl enable reportmate.service
