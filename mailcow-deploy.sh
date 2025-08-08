#!/bin/bash
# Mail Cow Professional Deployment Script for WSL Ubuntu
# Author: Professional DevOps Script
# Version: 2.0
# Compatible with: Ubuntu 20.04+ on WSL

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
MAILCOW_DIR="/opt/mailcow-dockerized"
BACKUP_DIR="/opt/mailcow-backups"
LOG_FILE="/var/log/mailcow-deployment.log"
COMPOSE_VERSION="2.21.0"
DOCKER_VERSION="24.0"

# Cloudflare API Configuration
CF_Global_API_Key="4ace45b7ba28ab70123400d7ad136599fb7fe"
CF_Origin_CA_Key="v1.0-c2f48ff91f27131fbc43257f-b7cd428991808127557a5aad6a9197b0cee466552404f5dd7797a6a75a074a2ba35bd93fcc81a66cdbf3f8b90ca2058296be977984c0dece4faa0300a336ed277a9e6346827313bd06"
CF_API_DNS="16-7xCRAy0sKGbf4jpNgPEld02VkOX4uNW6vn5Wo"
CF_Account_ID="94c410e126423c32c99f5b25f648f7d5"
CF_Zone_ID="93dbee2e70fd2e90257f876f8bc219e6"
CF_Domain="azab.services"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${PURPLE}[HEADER]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons."
        print_status "Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check WSL environment
check_wsl() {
    if ! grep -q "microsoft" /proc/version 2>/dev/null; then
        print_warning "This script is optimized for WSL environment."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "WSL environment detected. Proceeding..."
    fi
}

# Function to create log file
setup_logging() {
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chown "$USER:$USER" "$LOG_FILE"
    echo "=== Mail Cow Deployment Started: $(date) ===" >> "$LOG_FILE"
}

# Function to update system
update_system() {
    print_header "Updating System Packages"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git nano htop net-tools software-properties-common \
        apt-transport-https ca-certificates gnupg lsb-release jq unzip
    print_success "System packages updated successfully"
}

# Function to install Docker
install_docker() {
    print_header "Installing Docker"
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    # Configure Docker for WSL
    sudo mkdir -p /etc/docker
    cat << EOF | sudo tee /etc/docker/daemon.json
{
    "hosts": ["unix:///var/run/docker.sock"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF
    
    # Start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_success "Docker installed successfully"
}

# Function to install Docker Compose
install_docker_compose() {
    print_header "Installing Docker Compose"
    
    # Download and install Docker Compose
    COMPOSE_URL="https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64"
    sudo curl -L "$COMPOSE_URL" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for compatibility
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Verify installation
    docker-compose --version
    
    print_success "Docker Compose installed successfully"
}

# Function to install additional tools
install_tools() {
    print_header "Installing Additional Tools"
    
    # Install acme.sh for SSL certificates
    curl https://get.acme.sh | sh -s email=admin@"$CF_Domain"
    source ~/.bashrc
    
    # Install Cloudflare CLI (optional)
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb || sudo apt-get install -f -y
    rm -f cloudflared-linux-amd64.deb
    
    print_success "Additional tools installed successfully"
}

# Function to setup Cloudflare DNS records
setup_cloudflare_dns() {
    print_header "Setting up Cloudflare DNS Records"
    
    # Function to create/update DNS record
    create_dns_record() {
        local record_name="$1"
        local record_type="$2"
        local record_content="$3"
        local record_priority="${4:-}"
        
        print_status "Creating/Updating DNS record: $record_name"
        
        # Get current public IP
        if [ "$record_type" = "A" ]; then
            PUBLIC_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || curl -s ipinfo.io/ip)
            record_content="$PUBLIC_IP"
        fi
        
        # Check if record exists
        local record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_Zone_ID/dns_records?name=$record_name.$CF_Domain&type=$record_type" \
            -H "Authorization: Bearer $CF_API_DNS" \
            -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
        
        local api_data="{\"type\":\"$record_type\",\"name\":\"$record_name\",\"content\":\"$record_content\""
        if [ -n "$record_priority" ]; then
            api_data="$api_data,\"priority\":$record_priority"
        fi
        api_data="$api_data,\"ttl\":1}"
        
        if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
            # Update existing record
            curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_Zone_ID/dns_records/$record_id" \
                -H "Authorization: Bearer $CF_API_DNS" \
                -H "Content-Type: application/json" \
                -d "$api_data" > /dev/null
            print_success "Updated DNS record: $record_name.$CF_Domain"
        else
            # Create new record
            curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_Zone_ID/dns_records" \
                -H "Authorization: Bearer $CF_API_DNS" \
                -H "Content-Type: application/json" \
                -d "$api_data" > /dev/null
            print_success "Created DNS record: $record_name.$CF_Domain"
        fi
    }
    
    # Get public IP
    PUBLIC_IP=$(curl -s ipv4.icanhazip.com || curl -s ifconfig.me || curl -s ipinfo.io/ip)
    print_status "Detected public IP: $PUBLIC_IP"
    
    # Create main mail server records
    create_dns_record "mail" "A" "$PUBLIC_IP"
    create_dns_record "smtp" "CNAME" "mail.$CF_Domain"
    create_dns_record "imap" "CNAME" "mail.$CF_Domain"
    create_dns_record "pop3" "CNAME" "mail.$CF_Domain"
    
    # Create MX record
    create_dns_record "@" "MX" "mail.$CF_Domain" "10"
    
    # Create SPF record
    create_dns_record "@" "TXT" "v=spf1 mx a:mail.$CF_Domain -all"
    
    # Create DMARC record
    create_dns_record "_dmarc" "TXT" "v=DMARC1; p=quarantine; rua=mailto:dmarc@$CF_Domain"
    
    # Autodiscover records for Outlook
    create_dns_record "autodiscover" "CNAME" "mail.$CF_Domain"
    create_dns_record "_autodiscover._tcp" "SRV" "0 0 443 mail.$CF_Domain"
    
    # Autoconfig for Thunderbird
    create_dns_record "autoconfig" "CNAME" "mail.$CF_Domain"
    
    print_success "Cloudflare DNS records configured successfully"
}

# Function to setup DKIM keys automatically
setup_dkim_keys() {
    print_header "Setting up DKIM Keys"
    
    cd "$MAILCOW_DIR"
    
    # Wait for rspamd to be ready
    print_status "Waiting for rspamd service to be ready..."
    sleep 30
    
    # Generate DKIM key
    DKIM_KEY=$(docker-compose exec -T rspamd-mailcow rspamadm dkim_keygen -s dkim -b 2048 -d "$CF_Domain" -k /tmp/dkim.key 2>/dev/null || echo "")
    
    if [ -n "$DKIM_KEY" ]; then
        # Extract public key for DNS
        DKIM_PUBLIC=$(echo "$DKIM_KEY" | grep -A 10 "BEGIN PUBLIC KEY" | grep -B 10 "END PUBLIC KEY" | tr -d '\n' | sed 's/.*BEGIN PUBLIC KEY-----\(.*\)-----END PUBLIC KEY.*/\1/')
        
        # Create DKIM DNS record in Cloudflare
        DKIM_RECORD="v=DKIM1; k=rsa; p=$DKIM_PUBLIC"
        
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_Zone_ID/dns_records" \
            -H "Authorization: Bearer $CF_API_DNS" \
            -H "Content-Type: application/json" \
            -d "{\"type\":\"TXT\",\"name\":\"dkim._domainkey\",\"content\":\"$DKIM_RECORD\",\"ttl\":1}" > /dev/null
        
        print_success "DKIM keys generated and DNS record created"
    else
        print_warning "DKIM key generation will be completed after first startup"
    fi
}

# Function to setup SSL with Cloudflare Origin CA
setup_cloudflare_ssl() {
    print_header "Setting up Cloudflare SSL Integration"
    
    cd "$MAILCOW_DIR"
    
    # Create SSL directory
    sudo mkdir -p /etc/ssl/mail
    
    # Generate Origin CA Certificate using Cloudflare API
    cat << EOF > /tmp/origin_cert_request.json
{
  "hostnames": ["mail.$CF_Domain", "*.$CF_Domain"],
  "requested_validity": 5475,
  "request_type": "origin-rsa"
}
EOF
    
    # Request Origin Certificate
    CERT_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/certificates" \
        -H "Authorization: Bearer $CF_Origin_CA_Key" \
        -H "Content-Type: application/json" \
        -d @/tmp/origin_cert_request.json)
    
    # Extract certificate and private key
    echo "$CERT_RESPONSE" | jq -r '.result.certificate' > /tmp/origin.pem
    echo "$CERT_RESPONSE" | jq -r '.result.private_key' > /tmp/origin.key
    
    # Install certificates
    sudo cp /tmp/origin.pem /etc/ssl/mail/
    sudo cp /tmp/origin.key /etc/ssl/mail/
    sudo chmod 600 /etc/ssl/mail/origin.key
    sudo chmod 644 /etc/ssl/mail/origin.pem
    
    # Clean up
    rm -f /tmp/origin_cert_request.json /tmp/origin.pem /tmp/origin.key
    
    print_success "Cloudflare SSL certificates installed"
}

# Function to optimize system performance
optimize_system() {
    print_header "Optimizing System Performance"
    
    # Optimize kernel parameters for mail server
    cat << EOF | sudo tee /etc/sysctl.d/99-mailcow.conf
# Network optimizations for mail server
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
fs.file-max = 1000000
EOF
    
    sudo sysctl -p /etc/sysctl.d/99-mailcow.conf
    
    # Set up logrotate for mailcow logs
    cat << EOF | sudo tee /etc/logrotate.d/mailcow
/opt/mailcow-dockerized/data/logs/*/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        docker-compose -f /opt/mailcow-dockerized/docker-compose.yml restart nginx-mailcow
    endscript
}
EOF
    
    # Optimize Docker settings
    sudo mkdir -p /etc/systemd/system/docker.service.d
    cat << EOF | sudo tee /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --log-driver=json-file --log-opt=max-size=10m --log-opt=max-file=3
EOF
    
    sudo systemctl daemon-reload
    
    print_success "System performance optimizations applied"
}

# Function to setup monitoring
setup_monitoring() {
    print_header "Setting up Basic Monitoring"
    
    # Create monitoring script
    cat << 'EOF' | sudo tee /usr/local/bin/mailcow-monitor.sh > /dev/null
#!/bin/bash
# Mail Cow Monitoring Script

MAILCOW_DIR="/opt/mailcow-dockerized"
LOG_FILE="/var/log/mailcow-monitor.log"
ALERT_EMAIL="admin@azab.services"

cd "$MAILCOW_DIR"

# Check if all containers are running
CONTAINERS_DOWN=$(docker-compose ps -q | wc -l)
CONTAINERS_RUNNING=$(docker-compose ps | grep "Up" | wc -l)

if [ "$CONTAINERS_DOWN" -ne "$CONTAINERS_RUNNING" ]; then
    echo "$(date): Some containers are down" >> "$LOG_FILE"
    # Attempt to restart
    docker-compose up -d
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "$(date): Disk usage is ${DISK_USAGE}%" >> "$LOG_FILE"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ "$MEMORY_USAGE" -gt 90 ]; then
    echo "$(date): Memory usage is ${MEMORY_USAGE}%" >> "$LOG_FILE"
fi

# Check mail queue
QUEUE_SIZE=$(docker-compose exec -T postfix-mailcow postqueue -p | tail -n1 | awk '{print $5}' || echo "0")
if [ "$QUEUE_SIZE" -gt 100 ]; then
    echo "$(date): Mail queue size is $QUEUE_SIZE" >> "$LOG_FILE"
fi
EOF
    
    sudo chmod +x /usr/local/bin/mailcow-monitor.sh
    
    # Add monitoring to cron (every 5 minutes)
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/mailcow-monitor.sh") | crontab -
    
    print_success "Basic monitoring setup completed"
}

# Function to setup fail2ban for additional security
setup_fail2ban() {
    print_header "Setting up Enhanced Fail2ban Configuration"
    
    cd "$MAILCOW_DIR"
    
    # Create custom fail2ban configuration
    mkdir -p data/conf/fail2ban
    
    cat << EOF > data/conf/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[postfix-sasl]
enabled = true
filter = postfix-sasl
logpath = /var/log/mail.log
maxretry = 3
bantime = 3600

[dovecot]
enabled = true
filter = dovecot
logpath = /var/log/mail.log
maxretry = 3
bantime = 3600

[sogo-auth]
enabled = true
filter = sogo-auth
logpath = /var/log/sogo/sogo.log
maxretry = 3
bantime = 3600
EOF
    
    print_success "Enhanced Fail2ban configuration created"
}

# Function to create health check
create_health_check() {
    print_header "Creating Health Check Script"
    
    cat << 'EOF' | sudo tee /usr/local/bin/mailcow-healthcheck.sh > /dev/null
#!/bin/bash
# Mail Cow Health Check Script

MAILCOW_DIR="/opt/mailcow-dockerized"
DOMAIN="azab.services"

cd "$MAILCOW_DIR"

echo "=== Mail Cow Health Check - $(date) ==="

# Check container status
echo "Container Status:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}"

# Check SSL certificate expiry
echo -e "\nSSL Certificate Status:"
openssl s_client -connect mail.$DOMAIN:443 -servername mail.$DOMAIN < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Check mail ports
echo -e "\nPort Status:"
for port in 25 465 587 993 995 143 110; do
    if nc -z localhost $port; then
        echo "Port $port: OPEN"
    else
        echo "Port $port: CLOSED"
    fi
done

# Check disk usage
echo -e "\nDisk Usage:"
df -h /

# Check memory usage
echo -e "\nMemory Usage:"
free -h

# Check Docker stats
echo -e "\nDocker Container Resources:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo -e "\n=== Health Check Complete ==="
EOF
    
    sudo chmod +x /usr/local/bin/mailcow-healthcheck.sh
    
    print_success "Health check script created"
}
configure_firewall() {
    print_header "Configuring Firewall"
    
    # Install UFW if not present
    sudo apt install -y ufw
    
    # Reset UFW to defaults
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow Mail Cow ports
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw allow 25/tcp comment 'SMTP'
    sudo ufw allow 465/tcp comment 'SMTPS'
    sudo ufw allow 587/tcp comment 'SMTP Submission'
    sudo ufw allow 993/tcp comment 'IMAPS'
    sudo ufw allow 995/tcp comment 'POP3S'
    sudo ufw allow 110/tcp comment 'POP3'
    sudo ufw allow 143/tcp comment 'IMAP'
    sudo ufw allow 4190/tcp comment 'Sieve'
    
    # Enable UFW
    sudo ufw --force enable
    
    print_success "Firewall configured successfully"
}

# Function to check system requirements
check_requirements() {
    print_header "Checking System Requirements"
    
    # Check available memory
    MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$MEMORY_GB" -lt 4 ]; then
        print_warning "System has less than 4GB RAM. Mail Cow requires at least 4GB."
        print_warning "Current memory: ${MEMORY_GB}GB"
    else
        print_success "Memory requirement met: ${MEMORY_GB}GB"
    fi
    
    # Check available disk space
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -lt 20 ]; then
        print_warning "Available disk space is less than 20GB. Current: ${DISK_GB}GB"
    else
        print_success "Disk space requirement met: ${DISK_GB}GB available"
    fi
    
    # Check if ports are available
    check_ports=(80 443 25 465 587 993 995 110 143 4190)
    for port in "${check_ports[@]}"; do
        if netstat -tuln | grep -q ":$port "; then
            print_warning "Port $port is already in use"
        else
            print_status "Port $port is available"
        fi
    done
}

# Function to download and configure Mail Cow
download_mailcow() {
    print_header "Downloading Mail Cow"
    
    # Create directories
    sudo mkdir -p "$MAILCOW_DIR" "$BACKUP_DIR"
    sudo chown -R "$USER:$USER" "$MAILCOW_DIR" "$BACKUP_DIR"
    
    # Clone Mail Cow repository
    if [ -d "$MAILCOW_DIR/.git" ]; then
        print_status "Mail Cow already exists. Updating..."
        cd "$MAILCOW_DIR"
        git pull
    else
        print_status "Cloning Mail Cow repository..."
        git clone https://github.com/mailcow/mailcow-dockerized.git "$MAILCOW_DIR"
        cd "$MAILCOW_DIR"
    fi
    
    print_success "Mail Cow downloaded successfully"
}

# Function to configure Mail Cow with Cloudflare
configure_mailcow_cloudflare() {
    print_header "Configuring Mail Cow with Cloudflare Integration"
    
    cd "$MAILCOW_DIR"
    
    # Use the pre-configured domain
    DOMAIN_NAME="mail.$CF_Domain"
    
    read -p "Enter timezone (default: Africa/Cairo): " TIMEZONE
    TIMEZONE=${TIMEZONE:-"Africa/Cairo"}
    
    # Generate configuration
    ./generate_config.sh
    
    # Backup original mailcow.conf
    cp mailcow.conf mailcow.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    # Update configuration with Cloudflare settings
    sed -i "s/MAILCOW_HOSTNAME=.*/MAILCOW_HOSTNAME=$DOMAIN_NAME/" mailcow.conf
    sed -i "s/TZ=.*/TZ=$TIMEZONE/" mailcow.conf
    
    # Enable Let's Encrypt with Cloudflare DNS
    sed -i 's/SKIP_LETS_ENCRYPT=.*/SKIP_LETS_ENCRYPT=n/' mailcow.conf
    sed -i 's/SKIP_FAIL2BAN=.*/SKIP_FAIL2BAN=n/' mailcow.conf
    sed -i 's/SKIP_CLAMD=.*/SKIP_CLAMD=n/' mailcow.conf
    sed -i "s/ADDITIONAL_SAN=.*/ADDITIONAL_SAN=autoconfig.$CF_Domain,autodiscover.$CF_Domain/" mailcow.conf
    
    # Enable Cloudflare proxy mode
    sed -i 's/SKIP_HTTP_VERIFICATION=.*/SKIP_HTTP_VERIFICATION=y/' mailcow.conf
    
    # Additional Cloudflare-specific settings
    cat << EOF >> mailcow.conf

# Cloudflare Integration Settings
COMPOSE_PROJECT_NAME=mailcow-dockerized
MAILCOW_PASS_SCHEME=PBKDF2
ADDITIONAL_SERVER_NAMES=smtp.$CF_Domain,imap.$CF_Domain,pop3.$CF_Domain

# Cloudflare API for Let's Encrypt
CLOUDFLARE_EMAIL=admin@$CF_Domain
CLOUDFLARE_API_KEY=$CF_API_DNS

# Enable Cloudflare real IP
USE_WATCHDOG=y
WATCHDOG_NOTIFY_EMAIL=admin@$CF_Domain
EOF
    
    # Configure Cloudflare real IP in Nginx
    mkdir -p data/conf/nginx
    cat << 'EOF' > data/conf/nginx/cloudflare_real_ip.conf
# Cloudflare IP ranges for real IP detection
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

real_ip_header CF-Connecting-IP;
real_ip_recursive on;
EOF
    
    print_success "Mail Cow configured successfully for domain: $DOMAIN_NAME"
    print_status "Cloudflare integration enabled with real IP detection"
}

# Function to setup automatic updates
setup_auto_updates() {
    print_header "Setting up Automatic Updates"
    
    # Create update script
    cat << 'EOF' | sudo tee /usr/local/bin/mailcow-auto-update.sh > /dev/null
#!/bin/bash
# Mail Cow Auto Update Script

MAILCOW_DIR="/opt/mailcow-dockerized"
BACKUP_DIR="/opt/mailcow-backups"
LOG_FILE="/var/log/mailcow-updates.log"

cd "$MAILCOW_DIR"

echo "$(date): Starting automatic update check" >> "$LOG_FILE"

# Create backup before update
/usr/local/bin/mailcow-backup.sh

# Check for updates
if ./update.sh --check; then
    echo "$(date): Updates available, applying..." >> "$LOG_FILE"
    ./update.sh --skip-start
    docker-compose up -d
    echo "$(date): Updates completed successfully" >> "$LOG_FILE"
else
    echo "$(date): No updates available" >> "$LOG_FILE"
fi
EOF
    
    sudo chmod +x /usr/local/bin/mailcow-auto-update.sh
    
    # Schedule weekly updates (Sundays at 3 AM)
    (crontab -l 2>/dev/null; echo "0 3 * * 0 /usr/local/bin/mailcow-auto-update.sh") | crontab -
    
    print_success "Automatic updates configured"
}

# Function to setup email testing
setup_email_testing() {
    print_header "Setting up Email Testing Tools"
    
    # Install swaks for email testing
    sudo apt install -y swaks
    
    # Create email test script
    cat << EOF | sudo tee /usr/local/bin/test-mailcow.sh > /dev/null
#!/bin/bash
# Mail Cow Email Testing Script

DOMAIN="$CF_Domain"
MAIL_SERVER="mail.$CF_Domain"

echo "=== Testing Mail Cow Email Functionality ==="

# Test SMTP connection
echo "1. Testing SMTP connection..."
if nc -z \$MAIL_SERVER 587; then
    echo "✓ SMTP port 587 is open"
else
    echo "✗ SMTP port 587 is closed"
fi

# Test IMAP connection
echo -e "\n2. Testing IMAP connection..."
if nc -z \$MAIL_SERVER 993; then
    echo "✓ IMAP port 993 is open"
else
    echo "✗ IMAP port 993 is closed"
fi

# Test SSL certificate
echo -e "\n3. Testing SSL certificate..."
SSL_EXPIRY=\$(openssl s_client -connect \$MAIL_SERVER:443 -servername \$MAIL_SERVER < /dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
echo "SSL certificate expires: \$SSL_EXPIRY"

# Test DNS records
echo -e "\n4. Testing DNS records..."
echo "MX record: \$(dig +short MX \$DOMAIN)"
echo "SPF record: \$(dig +short TXT \$DOMAIN | grep spf)"
echo "DMARC record: \$(dig +short TXT _dmarc.\$DOMAIN)"

echo -e "\n=== Test Complete ==="
EOF
    
    sudo chmod +x /usr/local/bin/test-mailcow.sh
    
    print_success "Email testing tools installed"
}

# Function to create comprehensive documentation
create_documentation() {
    print_header "Creating Documentation"
    
    cat << EOF | sudo tee /opt/mailcow-documentation.md > /dev/null
# Mail Cow Server Documentation

## Server Information
- **Domain**: $CF_Domain
- **Mail Server**: mail.$CF_Domain
- **Installation Date**: $(date)
- **Installation Path**: $MAILCOW_DIR

## Access Information
- **Web Interface**: https://mail.$CF_Domain
- **Default Admin**: admin
- **Default Password**: moohoo (CHANGE IMMEDIATELY)

## DNS Configuration
All DNS records have been automatically configured in Cloudflare:
- mail.$CF_Domain (A record)
- smtp.$CF_Domain (CNAME)
- imap.$CF_Domain (CNAME)
- pop3.$CF_Domain (CNAME)
- autodiscover.$CF_Domain (CNAME)
- autoconfig.$CF_Domain (CNAME)
- MX record for $CF_Domain
- SPF, DMARC, and DKIM records

## Email Client Configuration
### IMAP Settings
- Server: imap.$CF_Domain
- Port: 993
- Security: SSL/TLS

### SMTP Settings
- Server: smtp.$CF_Domain
- Port: 587
- Security: STARTTLS

### POP3 Settings
- Server: pop3.$CF_Domain
- Port: 995
- Security: SSL/TLS

## Maintenance Commands
\`\`\`bash
# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Update Mail Cow
./update.sh

# Create backup
/usr/local/bin/mailcow-backup.sh

# Run health check
/usr/local/bin/mailcow-healthcheck.sh

# Test email functionality
/usr/local/bin/test-mailcow.sh
\`\`\`

## File Locations
- **Configuration**: $MAILCOW_DIR/mailcow.conf
- **Backups**: $BACKUP_DIR
- **Logs**: /var/log/mailcow-*.log
- **SSL Certificates**: /etc/ssl/mail/

## Security Features Enabled
- Fail2ban for brute force protection
- Cloudflare DDoS protection
- SSL/TLS encryption
- SPF, DKIM, and DMARC authentication
- Real IP detection through Cloudflare

## Monitoring
- Automatic health checks every 5 minutes
- Weekly automatic updates
- Daily backups with 7-day retention
- Log rotation configured

## Troubleshooting
1. Check container status: \`docker-compose ps\`
2. View specific service logs: \`docker-compose logs [service_name]\`
3. Restart all services: \`docker-compose restart\`
4. Check system resources: \`/usr/local/bin/mailcow-healthcheck.sh\`

## Support
- Official Documentation: https://mailcow.github.io/mailcow-dockerized-docs/
- Community Forum: https://community.mailcow.email/
- GitHub Issues: https://github.com/mailcow/mailcow-dockerized/issues
EOF
    
    print_success "Documentation created at /opt/mailcow-documentation.md"
}
create_backup_script() {
    print_header "Creating Backup Script"
    
    cat << 'EOF' | sudo tee /usr/local/bin/mailcow-backup.sh > /dev/null
#!/bin/bash
# Mail Cow Backup Script

MAILCOW_DIR="/opt/mailcow-dockerized"
BACKUP_DIR="/opt/mailcow-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mailcow_backup_$DATE"

cd "$MAILCOW_DIR"

# Create backup
echo "Creating backup: $BACKUP_NAME"
./helper-scripts/backup_and_restore.sh backup all "$BACKUP_DIR/$BACKUP_NAME"

# Keep only last 7 backups
find "$BACKUP_DIR" -name "mailcow_backup_*" -type d -mtime +7 -exec rm -rf {} \;

echo "Backup completed: $BACKUP_DIR/$BACKUP_NAME"
EOF
    
    sudo chmod +x /usr/local/bin/mailcow-backup.sh
    
    # Create daily backup cron job
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/mailcow-backup.sh") | crontab -
    
    print_success "Backup script created and scheduled"
}

# Function to start Mail Cow
start_mailcow() {
    print_header "Starting Mail Cow Services"
    
    cd "$MAILCOW_DIR"
    
    # Pull latest images
    docker-compose pull
    
    # Start services
    docker-compose up -d
    
    # Wait for services to start
    print_status "Waiting for services to start..."
    sleep 30
    
    # Check service status
    if docker-compose ps | grep -q "Up"; then
        print_success "Mail Cow services started successfully"
    else
        print_error "Some services failed to start. Check logs with: docker-compose logs"
        return 1
    fi
}

# Function to display final information
display_final_info() {
    print_header "Deployment Complete!"
    
    echo -e "\n${GREEN}=== Mail Cow Installation Summary ===${NC}"
    echo -e "${CYAN}Installation Directory:${NC} $MAILCOW_DIR"
    echo -e "${CYAN}Backup Directory:${NC} $BACKUP_DIR"
    echo -e "${CYAN}Log File:${NC} $LOG_FILE"
    echo -e "${CYAN}Domain:${NC} $CF_Domain"
    echo -e "${CYAN}Mail Server:${NC} https://mail.$CF_Domain"
    echo -e "${CYAN}Web Interface:${NC} https://mail.$CF_Domain"
    echo -e "${CYAN}Default Admin:${NC} admin"
    echo -e "${CYAN}Default Password:${NC} moohoo"
    
    echo -e "\n${YELLOW}Cloudflare Configuration:${NC}"
    echo "• DNS records have been automatically configured"
    echo "• SSL certificates are managed by Cloudflare"
    echo "• Real IP detection is enabled"
    echo "• All subdomains (smtp, imap, pop3) are configured"
    
    echo -e "\n${YELLOW}DNS Records Created:${NC}"
    echo "• mail.$CF_Domain → A record"
    echo "• smtp.$CF_Domain → CNAME to mail"
    echo "• imap.$CF_Domain → CNAME to mail"
    echo "• pop3.$CF_Domain → CNAME to mail"
    echo "• autodiscover.$CF_Domain → CNAME to mail"
    echo "• autoconfig.$CF_Domain → CNAME to mail"
    echo "• MX record for $CF_Domain"
    echo "• SPF, DMARC records configured"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Access web interface at https://mail.$CF_Domain"
    echo "2. Login with admin/moohoo and change password immediately"
    echo "3. Verify DNS propagation (may take a few minutes)"
    echo "4. Configure DKIM keys in Cloudflare DNS"
    echo "5. Create your email accounts"
    echo "6. Test email sending/receiving"
    
    echo -e "\n${YELLOW}Email Client Settings:${NC}"
    echo "• IMAP Server: imap.$CF_Domain (Port 993, SSL)"
    echo "• SMTP Server: smtp.$CF_Domain (Port 587, STARTTLS)"
    echo "• POP3 Server: pop3.$CF_Domain (Port 995, SSL)"
    
    echo -e "\n${YELLOW}Additional Tools Installed:${NC}"
    echo "• Health Check: /usr/local/bin/mailcow-healthcheck.sh"
    echo "• Email Testing: /usr/local/bin/test-mailcow.sh"
    echo "• Auto Updates: /usr/local/bin/mailcow-auto-update.sh"
    echo "• Monitoring: /usr/local/bin/mailcow-monitor.sh"
    echo "• Documentation: /opt/mailcow-documentation.md"
    
    echo -e "\n${YELLOW}Automated Features:${NC}"
    echo "• Daily backups (2 AM)"
    echo "• Health monitoring (every 5 minutes)"
    echo "• Weekly updates (Sundays 3 AM)"
    echo "• Log rotation"
    echo "• Performance optimization"
    echo "• Enhanced fail2ban protection"
    
    echo -e "\n${YELLOW}Post-Installation Tasks:${NC}"
    echo "1. Run health check: /usr/local/bin/mailcow-healthcheck.sh"
    echo "2. Test email: /usr/local/bin/test-mailcow.sh"
    echo "3. Review documentation: /opt/mailcow-documentation.md"
    echo "4. Setup admin email account"
    echo "5. Configure email clients"
    
    echo -e "\n${YELLOW}Useful Commands:${NC}"
    echo "• View logs: docker-compose logs -f"
    echo "• Stop services: docker-compose down"
    echo "• Start services: docker-compose up -d"
    echo "• Update Mail Cow: ./update.sh"
    echo "• Create backup: /usr/local/bin/mailcow-backup.sh"
    echo "• Check DKIM keys: docker-compose exec rspamd-mailcow rspamadm dkim_keygen -s dkim -b 2048 -d $CF_Domain"
    
    echo -e "\n${RED}Important Security Notes:${NC}"
    echo "• Change default admin password immediately"
    echo "• Review firewall settings"
    echo "• Monitor system resources regularly"
    echo "• Keep system and Mail Cow updated"
    
    print_success "Mail Cow deployment completed successfully!"
}

# Function to handle cleanup on exit
cleanup() {
    if [ $? -ne 0 ]; then
        print_error "Script failed. Check $LOG_FILE for details."
        echo "You can retry the installation or check the documentation."
    fi
}

# Main execution function
main() {
    trap cleanup EXIT
    
    print_header "Mail Cow Professional Deployment Script"
    print_status "Starting deployment process..."
    
    # Pre-flight checks
    check_root
    check_wsl
    setup_logging
    
    # System preparation
    update_system
    check_requirements
    
    # Docker installation
    if ! command -v docker &> /dev/null; then
        install_docker
        print_warning "Docker installed. You may need to log out and log back in."
        print_status "Continuing with current session..."
    else
        print_status "Docker already installed"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        install_docker_compose
    else
        print_status "Docker Compose already installed"
    fi
    
    # Install additional tools
    install_tools
    
    # System optimization
    optimize_system
    
    # Security configuration
    configure_firewall
    setup_fail2ban
    
    # Cloudflare setup
    setup_cloudflare_dns
    setup_cloudflare_ssl
    
    # Mail Cow setup
    download_mailcow
    configure_mailcow_cloudflare
    create_backup_script
    start_mailcow
    
    # Post-installation setup
    setup_dkim_keys
    setup_monitoring
    setup_auto_updates
    setup_email_testing
    create_documentation
    
    # Final steps
    display_final_info
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
