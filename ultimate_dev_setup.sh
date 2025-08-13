#!/bin/bash

# Ultimate Development Tools Installation Script
# For Ubuntu 24.04 LTS - Complete Development Environment Setup
# Author: Claude AI Assistant
# Version: 2.1 (Improved & Fixed by Copilot)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check and install package
install_package() {
    local package=$1
    local description=$2
    if dpkg -l | grep -q "^ii  $package "; then
        info "$description already installed ✓"
    else
        log "Installing $description..."
        sudo apt install -y "$package"
    fi
}

# Function to install snap package
install_snap() {
    local package=$1
    local description=$2
    local channel=${3:-stable}
    local classic=${4:-false}
    if snap list | grep -q "^$package "; then
        info "$description already installed ✓"
    else
        log "Installing $description via snap..."
        if [ "$classic" = "true" ]; then
            sudo snap install "$package" "--$channel" --classic
        else
            sudo snap install "$package" "--$channel"
        fi
    fi
}

# Function to install from .deb file
install_deb() {
    local url=$1
    local description=$2
    local filename=$(basename "$url")
    log "Installing $description..."
    wget -O "/tmp/$filename" "$url"
    sudo dpkg -i "/tmp/$filename" || sudo apt -f install -y
    rm "/tmp/$filename"
}

# System information
print_system_info() {
    log "=== SYSTEM INFORMATION ==="
    info "OS: $(lsb_release -d | cut -f2)"
    info "Kernel: $(uname -r)"
    info "Architecture: $(uname -m)"
    info "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    info "CPU: $(nproc) cores"
    info "Disk Space: $(df -h / | awk 'NR==2 {print $4}') available"
    echo
}

# Update system
update_system() {
    log "=== UPDATING SYSTEM ==="
    sudo apt update && sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
}

# Install essential system tools
install_essential_tools() {
    log "=== INSTALLING ESSENTIAL SYSTEM TOOLS ==="
    install_package "curl" "cURL"
    install_package "wget" "Wget"
    install_package "git" "Git"
    install_package "vim" "Vim Editor"
    install_package "nano" "Nano Editor"
    install_package "htop" "Htop Process Monitor"
    install_package "tree" "Tree Directory Listing"
    install_package "unzip" "Unzip Utility"
    install_package "zip" "Zip Utility"
    install_package "p7zip-full" "7-Zip"
    install_package "software-properties-common" "Software Properties Common"
    install_package "apt-transport-https" "APT HTTPS Transport"
    install_package "ca-certificates" "CA Certificates"
    install_package "gnupg" "GNU Privacy Guard"
    install_package "lsb-release" "LSB Release"
    install_package "build-essential" "Build Essential"
    install_package "make" "Make"
    install_package "cmake" "CMake"
    install_package "gcc" "GCC Compiler"
    install_package "g++" "G++ Compiler"
    install_package "gdb" "GNU Debugger"
    install_package "valgrind" "Valgrind Memory Debugger"
    install_package "strace" "System Call Tracer"
    install_package "ltrace" "Library Call Tracer"
}

# Install networking and security tools
install_network_security_tools() {
    log "=== INSTALLING NETWORKING & SECURITY TOOLS ==="
    install_package "net-tools" "Network Tools"
    install_package "netstat-nat" "Netstat NAT"
    install_package "nmap" "Network Mapper"
    install_package "tcpdump" "TCP Dump"
    install_package "wireshark" "Wireshark"
    install_package "openssh-server" "OpenSSH Server"
    install_package "openssh-client" "OpenSSH Client"
    install_package "fail2ban" "Fail2Ban"
    install_package "ufw" "Uncomplicated Firewall"
    install_package "iptables" "IP Tables"
    install_package "openssl" "OpenSSL"
    install_package "certbot" "Certbot (Let's Encrypt)"
}

# Install development languages and runtimes
install_programming_languages() {
    log "=== INSTALLING PROGRAMMING LANGUAGES & RUNTIMES ==="
    # PHP ecosystem (install early for Composer)
    install_package "php" "PHP"
    install_package "php-cli" "PHP CLI"
    install_package "php-zip" "PHP Zip"
    install_package "php-mbstring" "PHP Mbstring"
    install_package "php-xml" "PHP XML"
    # Python ecosystem
    install_package "python3" "Python 3"
    install_package "python3-pip" "Python 3 PIP"
    install_package "python3-venv" "Python 3 Virtual Environment"
    install_package "python3-dev" "Python 3 Development Headers"
    install_package "python3-setuptools" "Python 3 Setuptools"
    install_package "python3-wheel" "Python 3 Wheel"
    install_package "pipenv" "Pipenv"
    # Node.js ecosystem
    if ! command_exists node; then
        log "Installing Node.js via NodeSource..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt install -y nodejs
    else
        info "Node.js already installed ✓"
    fi
    # Install yarn
    if ! command_exists yarn; then
        log "Installing Yarn..."
        curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
        echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
        sudo apt update && sudo apt install -y yarn
    else
        info "Yarn already installed ✓"
    fi
    # Install Composer
    if ! command_exists composer; then
        log "Installing Composer..."
        curl -sS https://getcomposer.org/installer | php
        sudo mv composer.phar /usr/local/bin/composer
        sudo chmod +x /usr/local/bin/composer
    else
        info "Composer already installed ✓"
    fi
    # Java ecosystem
    install_package "default-jdk" "Java Development Kit"
    install_package "maven" "Apache Maven"
    install_package "gradle" "Gradle"
    # Go language
    if ! command_exists go; then
        log "Installing Go language..."
        GO_VERSION="1.21.5"
        wget "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    else
        info "Go already installed ✓"
    fi
    # Rust language
    if ! command_exists rustc; then
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    else
        info "Rust already installed ✓"
    fi
    # Ruby ecosystem
    install_package "ruby" "Ruby"
    install_package "ruby-dev" "Ruby Development Headers"
    install_package "rubygems" "Ruby Gems"
    # Other languages
    install_package "lua5.4" "Lua"
    install_package "perl" "Perl"
    install_package "r-base" "R Programming Language"
}

# تابع باقي السكربت كما هو في النسخة الأصلية المرفقة أعلاه، فقط صحح أي خطأ مشابه

# Install databases
install_databases() {
    log "=== INSTALLING DATABASES ==="
    
    # MySQL/MariaDB
    install_package "mariadb-server" "MariaDB Server"
    install_package "mariadb-client" "MariaDB Client"
    install_package "mycli" "MySQL CLI with auto-completion"
    
    # PostgreSQL
    install_package "postgresql" "PostgreSQL"
    install_package "postgresql-contrib" "PostgreSQL Contrib"
    install_package "pgcli" "PostgreSQL CLI with auto-completion"
    
    # SQLite
    install_package "sqlite3" "SQLite3"
    
    # Redis
    install_package "redis-server" "Redis Server"
    install_package "redis-tools" "Redis Tools"
    
    
    # Elasticsearch
    if ! command_exists elasticsearch; then
        log "Installing Elasticsearch..."
        wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
        echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
        sudo apt update && sudo apt install -y elasticsearch
    else
        info "Elasticsearch already installed ✓"
    fi
}

# Install web servers and reverse proxies
install_web_servers() {
    log "=== INSTALLING WEB SERVERS & REVERSE PROXIES ==="
    
    install_package "nginx" "Nginx Web Server"
    install_package "apache2" "Apache2 Web Server"
    install_package "haproxy" "HAProxy Load Balancer"
    
    # Caddy web server
    if ! command_exists caddy; then
        log "Installing Caddy..."
        sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        sudo apt update && sudo apt install -y caddy
    else
        info "Caddy already installed ✓"
    fi
}

# Install containerization tools
install_containerization() {
    log "=== INSTALLING CONTAINERIZATION TOOLS ==="
    
    # Docker
    if ! command_exists docker; then
        log "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$USER"
    else
        info "Docker already installed ✓"
    fi
    
    # Docker Compose standalone
    if ! command_exists docker-compose; then
        log "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        info "Docker Compose already installed ✓"
    fi
    
    # Kubernetes tools
    if ! command_exists kubectl; then
        log "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    else
        info "kubectl already installed ✓"
    fi
    
    # Minikube
    if ! command_exists minikube; then
        log "Installing Minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
    else
        info "Minikube already installed ✓"
    fi
    
    # Helm
    if ! command_exists helm; then
        log "Installing Helm..."
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt update && sudo apt install -y helm
    else
        info "Helm already installed ✓"
    fi
}

# Install cloud and DevOps tools
install_cloud_devops() {
    log "=== INSTALLING CLOUD & DEVOPS TOOLS ==="
    
    # Terraform
    if ! command_exists terraform; then
        log "Installing Terraform..."
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
    else
        info "Terraform already installed ✓"
    fi
    
    # Ansible
    install_package "ansible" "Ansible"
    
    # AWS CLI
    if ! command_exists aws; then
        log "Installing AWS CLI..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
        unzip /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install
        rm -rf /tmp/aws /tmp/awscliv2.zip
    else
        info "AWS CLI already installed ✓"
    fi
    
    # Google Cloud SDK
    if ! command_exists gcloud; then
        log "Installing Google Cloud SDK..."
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt update && sudo apt install -y google-cloud-cli
    else
        info "Google Cloud SDK already installed ✓"
    fi
    
    # Azure CLI
    if ! command_exists az; then
        log "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        info "Azure CLI already installed ✓"
    fi
    
    # Jenkins
    if ! command_exists jenkins; then
        log "Installing Jenkins from official repository..."
        wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
        sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt update && sudo apt install -y jenkins
    else
        info "Jenkins already installed ✓"
    fi
}

# Install monitoring and logging tools
install_monitoring_logging() {
    log "=== INSTALLING MONITORING & LOGGING TOOLS ==="
    
    install_package "prometheus" "Prometheus"
    
    if ! command_exists grafana-server; then
        log "Installing Grafana from official repository..."
        sudo apt install -y software-properties-common
        wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
        echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
        sudo apt update && sudo apt install -y grafana
    else
        info "Grafana already installed ✓"
    fi
    
    install_package "logrotate" "Logrotate"
    install_package "rsyslog" "Rsyslog"
    install_package "collectd" "Collectd"
    
    # ELK Stack components
    if ! command_exists logstash; then
        info "Logstash available via Elasticsearch repository"
    fi
    
    if ! command_exists kibana; then
        info "Kibana available via Elasticsearch repository"
    fi
}

# Install development tools and IDEs
install_dev_tools() {
    log "=== INSTALLING DEVELOPMENT TOOLS & IDEs ==="
    
    # Text editors and IDEs
    install_snap "code" "Visual Studio Code" "stable" "true"
    install_snap "sublime-text" "Sublime Text" "stable" "true"
    install_snap "intellij-idea-community" "IntelliJ IDEA Community" "stable" "true"
    install_snap "pycharm-community" "PyCharm Community" "stable" "true"
    
    # Version control
    install_package "git-lfs" "Git Large File Storage"
    install_package "tig" "Text-mode interface for Git"
    install_package "gitk" "Git GUI"
    install_package "meld" "Meld Diff Viewer"
    
    # API testing
    install_snap "postman" "Postman"
    install_package "httpie" "HTTPie"
    install_package "jq" "JSON Processor"
    install_package "yq" "YAML Processor"
    
    # Database tools
    install_snap "dbeaver-ce" "DBeaver Community Edition"
    
    # Terminal improvements
    install_package "tmux" "Terminal Multiplexer"
    install_package "screen" "Screen"
    install_package "fish" "Fish Shell"
    install_package "zsh" "Zsh Shell"
    
    # Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        info "Oh My Zsh already installed ✓"
    fi
    
    # Productivity tools
    iinstall_package "fzf" "Fuzzy Finder" || true
    install_package "ripgrep" "Ripgrep (rg)" || true
    install_package "fd-find" "Modern find alternative" || true
    install_package "bat" "Better cat with syntax highlighting" || true
    install_package "eza" "Modern ls replacement (eza)" || {
    log "Trying to install exa via cargo..."
     if command_exists cargo; then
    cargo install exa
     else
    log "Skipped: Neither eza installed nor cargo available"
     fi
  }

    install_package "dust" "Modern du replacement" || true
    install_package "tokei" "Code statistics" || true
}

# Install media and graphics tools
install_media_graphics() {
    log "=== INSTALLING MEDIA & GRAPHICS TOOLS ==="
    
    install_package "imagemagick" "ImageMagick"
    install_package "graphicsmagick" "GraphicsMagick"
    install_package "ffmpeg" "FFmpeg"
    install_package "gimp" "GIMP"
    install_package "inkscape" "Inkscape"
    install_snap "blender" "Blender"
    install_package "vlc" "VLC Media Player"
    install_package "audacity" "Audacity"
}

# ─────────────────────────────────────────────────────────────
# 🖥️ Install system monitoring tools
install_system_monitoring() {
    log "=== INSTALLING SYSTEM MONITORING TOOLS ==="

    # 📊 Disk I/O monitoring
    install_package "iotop" "I/O Monitor"
    # ───────────────────────────────

    # 🌐 Network monitoring
    install_package "iftop" "Network Monitor"
    install_package "nethogs" "Network Top"
    # ───────────────────────────────

    # 🧠 System-wide monitoring
    install_package "atop" "Advanced System Monitor"
    install_package "glances" "System Monitor"
    # ───────────────────────────────

    # 💻 System info tools
    install_package "neofetch" "System Information"
    install_package "lm-sensors" "Hardware Sensors"
    install_package "smartmontools" "S.M.A.R.T. Monitoring Tools"
    # ───────────────────────────────

    # 🔥 System stress testing
    install_package "stress" "System Stress Testing"
    install_package "stress-ng" "Advanced Stress Testing"
    # ───────────────────────────────
}

# ─────────────────────────────────────────────────────────────
# 🛡️ Install security tools
install_security_tools() {
    log "=== INSTALLING SECURITY TOOLS ==="

    # 🦠 Antivirus tools
    install_package "clamav" "ClamAV Antivirus"
    # ───────────────────────────────

    # 🕵️‍♂️ Rootkit scanners
    install_package "rkhunter" "Rootkit Hunter"
    install_package "chkrootkit" "Check Rootkit"
    # ───────────────────────────────

    # 🧾 Security auditing & file integrity
    install_package "lynis" "Security Auditing Tool"
    install_package "aide" "Advanced Intrusion Detection Environment"
    # ───────────────────────────────

    # 🔒 Mandatory access control (MAC)
    install_package "apparmor" "AppArmor Security Module"
    install_package "apparmor-utils" "AppArmor Utilities"
    # ───────────────────────────────
}

# Install backup and sync tools
install_backup_sync() {
    log "=== INSTALLING BACKUP & SYNC TOOLS ==="
    
    install_package "rsync" "Rsync"
    install_package "rclone" "Cloud Storage Sync"
    install_package "duplicity" "Encrypted Backup"
    install_package "borgbackup" "Borg Backup"
    install_snap "nextcloud" "Nextcloud Client"
}

# Install communication tools
install_communication() {
    log "=== INSTALLING COMMUNICATION TOOLS ==="
    
    install_snap "discord" "Discord"
    install_snap "slack" "Slack"
    install_snap "telegram-desktop" "Telegram"
    install_snap "zoom-client" "Zoom"
    install_package "thunderbird" "Thunderbird Email Client"
}

# Install future-proof tools and emerging technologies
install_future_tools() {
    log "=== INSTALLING FUTURE-PROOF & EMERGING TECH TOOLS ==="

    # Machine Learning and AI (inside virtualenv)
    info "Creating virtual environment for Python ML libraries..."
    VENV_PATH="$HOME/venvs/ml-env"
    mkdir -p "$VENV_PATH"

    if [ ! -d "$VENV_PATH/bin" ]; then
        python3 -m venv "$VENV_PATH"
    fi

    source "$VENV_PATH/bin/activate"

    info "Installing Python ML libraries inside virtualenv..."
    pip install --upgrade pip
    pip install numpy pandas scikit-learn matplotlib seaborn jupyter tensorflow torch transformers qiskit cirq

    deactivate
    info "Deactivated virtual environment after ML tools installation ✓"

    # Blockchain development
    if ! command_exists solc; then
        log "Installing Solidity compiler..."
        sudo snap install solc
    else
        info "Solidity compiler already installed ✓"
    fi

    # Web3 tools
    npm install -g truffle ganache-cli hardhat web3 ethers

    # IoT development
    install_package "mosquitto" "MQTT Broker"
    install_package "mosquitto-clients" "MQTT Clients"

    # AR/VR development prerequisites
    install_package "libassimp-dev" "Asset Import Library"
    install_package "libgl1-mesa-dev" "OpenGL Development"
    install_package "libglu1-mesa-dev" "OpenGL Utilities"

    # Edge computing tools
    if ! command_exists k3s; then
        log "Installing K3s (Lightweight Kubernetes)..."
        curl -sfL https://get.k3s.io | sh -
    else
        info "K3s already installed ✓"
    fi

    # Container scanning and security
    if ! command_exists trivy; then
        log "Installing Trivy (Container Scanner)..."
        sudo apt update && sudo apt install -y wget apt-transport-https gnupg lsb-release
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt update && sudo apt install -y trivy
    else
        info "Trivy already installed ✓"
    fi

    # GitOps tools
    if ! command_exists argocd; then
        log "Installing ArgoCD CLI..."
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    else
        info "ArgoCD CLI already installed ✓"
    fi

    # Service mesh
    if ! command_exists istioctl; then
        log "Installing Istio..."
        curl -L https://istio.io/downloadIstio | sh -
        sudo mv istio-*/bin/istioctl /usr/local/bin/
        rm -rf istio-*
    else
        info "Istio already installed ✓"
    fi
}


# Configure services
configure_services() {
    log "=== CONFIGURING SERVICES ==="
    
    # Enable and start essential services
    sudo systemctl enable nginx || true
    sudo systemctl enable docker || true
    sudo systemctl enable redis-server || true
    sudo systemctl enable postgresql || true
    sudo systemctl enable mariadb || true
    
    # Configure firewall
    info "Configuring UFW firewall..."
    sudo ufw --force enable
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    
    # Configure Git (if not configured)
    if [ -z "$(git config --global user.name)" ]; then
        warning "Git user.name not configured. Please run: git config --global user.name 'Your Name'"
    fi
    if [ -z "$(git config --global user.email)" ]; then
        warning "Git user.email not configured. Please run: git config --global user.email 'your.email@example.com'"
    fi
}

# Create useful aliases and functions
create_aliases() {
    log "=== CREATING USEFUL ALIASES ==="
    
    cat >> ~/.bashrc << 'EOF'

# Development aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps auxf'
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias mkdir='mkdir -pv'
alias histg='history | grep'
alias myip='curl http://ipecho.net/plain; echo'
alias logs='sudo journalctl -f'
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
alias search='apt search'
alias dstop='docker stop $(docker ps -a -q)'
alias dkill='docker kill $(docker ps -q)'
alias dclean='docker system prune -af'
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate'

# Function to create and enter directory
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Function to extract any archive
extract() {
    if [ -f "$1" ] ; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Function to find and kill process by name
killp() {
    ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs sudo kill -9
}

# Function to show disk usage of current directory
usage() {
    du -sh * 2>/dev/null | sort -hr
}

# Function to show listening ports
ports() {
    netstat -tuln
}

# Function to backup file/directory with timestamp
backup() {
    cp -r "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
}
EOF

    info "Useful aliases and functions added to ~/.bashrc"
}

# Performance optimization
optimize_system() {
    log "=== OPTIMIZING SYSTEM PERFORMANCE ==="
    
    # Optimize swap usage
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    
    # Optimize file system
    echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
    
    # Optimize network
    cat >> /tmp/network_optimizations << 'EOF'
# Network optimizations
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
EOF
    
    sudo tee -a /etc/sysctl.conf < /tmp/network_optimizations
    rm /tmp/network_optimizations
    
    # Apply optimizations
    sudo sysctl -p
    
    info "System optimizations applied"
}

# Cleanup function
cleanup_installation() {
    log "=== CLEANING UP INSTALLATION ==="
    
    # Clean package cache
    sudo apt autoremove -y
    sudo apt autoclean
    
    # Clean snap cache
    sudo snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        sudo snap remove "$snapname" --revision="$revision" 2>/dev/null || true
    done
    
    # Clean temporary files
    rm -rf /tmp/*
    
    # Update locate database
    sudo updatedb 2>/dev/null || true
    
    info "Cleanup completed"
}

# Generate system report (HTML format)
generate_report() {
    log "=== GENERATING INSTALLATION REPORT ==="
    
    REPORT_HTML="$HOME/system_setup_report_$(date +%Y%m%d_%H%M%S).html"
    REPORT_TXT="$HOME/system_setup_report_$(date +%Y%m%d_%H%M%S).txt"
    
    # Get system information
    OS_INFO=$(lsb_release -d | cut -f2)
    KERNEL_INFO=$(uname -r)
    ARCH_INFO=$(uname -m)
    MEMORY_INFO=$(free -h | awk '/^Mem:/ {print $2}')
    CPU_INFO=$(nproc)
    DISK_INFO=$(df -h / | awk 'NR==2 {print $4}')
    UPTIME_INFO=$(uptime -p)
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    
    # Function to check tool and return status
    get_tool_status() {
        local tool=$1
        local version_cmd=$2
        if command_exists "$tool"; then
            if [ -n "$version_cmd" ]; then
                echo "<span class='status-success'>✓</span> $($version_cmd 2>/dev/null | head -n1)"
            else
                echo "<span class='status-success'>✓</span> Installed"
            fi
        else
            echo "<span class='status-error'>✗</span> Not installed"
        fi
    }
    
    # Generate HTML Report
    cat > "$REPORT_HTML" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Setup Report - $(date +%Y-%m-%d)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            line-height: 1.6;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            text-align: center;
        }
        
        .header h1 {
            color: #2c3e50;
            font-size: 3em;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .header .subtitle {
            color: #7f8c8d;
            font-size: 1.2em;
            margin-bottom: 20px;
        }
        
        .timestamp {
            background: linear-gradient(45deg, #ff6b6b, #ee5a24);
            color: white;
            padding: 10px 20px;
            border-radius: 50px;
            display: inline-block;
            font-weight: bold;
        }
        
        .section {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease;
        }
        
        .section:hover {
            transform: translateY(-5px);
        }
        
        .section h2 {
            color: #2c3e50;
            font-size: 2em;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
            display: flex;
            align-items: center;
        }
        
        .section-icon {
            font-size: 1.2em;
            margin-right: 15px;
            width: 40px;
            height: 40px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .card {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 20px;
            border-radius: 15px;
            border-left: 5px solid #667eea;
            transition: all 0.3s ease;
        }
        
        .card:hover {
            transform: scale(1.02);
            box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
        }
        
        .card h3 {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 1.2em;
        }
        
        .card p {
            color: #555;
            margin: 5px 0;
        }
        
        .tool-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .tool-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            border-left: 4px solid #28a745;
            font-family: 'Courier New', monospace;
            transition: all 0.3s ease;
        }
        
        .tool-item:hover {
            background: #e9ecef;
            transform: translateX(5px);
        }
        
        .status-success {
            color: #28a745;
            font-weight: bold;
            font-size: 1.2em;
        }
        
        .status-error {
            color: #dc3545;
            font-weight: bold;
            font-size: 1.2em;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 10px;
        }
        
        .commands-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
        }
        
        .command-block {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 20px;
            border-radius: 10px;
            font-family: 'Courier New', monospace;
            overflow-x: auto;
        }
        
        .command-block h4 {
            color: #3498db;
            margin-bottom: 15px;
            font-size: 1.1em;
        }
        
        .command-block code {
            background: #34495e;
            padding: 5px 10px;
            border-radius: 5px;
            display: block;
            margin: 5px 0;
            color: #2ecc71;
        }
        
        .footer {
            text-align: center;
            padding: 30px;
            color: rgba(255, 255, 255, 0.8);
            font-size: 1.1em;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background: #ecf0f1;
            border-radius: 4px;
            overflow: hidden;
            margin: 10px 0;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(45deg, #667eea, #764ba2);
            border-radius: 4px;
            animation: progressAnimation 2s ease-in-out;
        }
        
        @keyframes progressAnimation {
            from { width: 0%; }
            to { width: var(--progress); }
        }
        
        .floating-action {
            position: fixed;
            bottom: 30px;
            right: 30px;
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border: none;
            border-radius: 50%;
            width: 60px;
            height: 60px;
            font-size: 1.5em;
            cursor: pointer;
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.3);
            transition: all 0.3s ease;
        }
        
        .floating-action:hover {
            transform: scale(1.1) rotate(15deg);
        }
        
        @media (max-width: 768px) {
            .container {
                padding: 10px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>🚀 System Setup Report</h1>
            <p class="subtitle">Ultimate Development Environment Installation</p>
            <div class="timestamp">Generated on $(date)</div>
        </header>

        <section class="section">
            <h2><span class="section-icon">💻</span>System Information</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-number">$CPU_INFO</div>
                    <div>CPU Cores</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$MEMORY_INFO</div>
                    <div>Total Memory</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$DISK_INFO</div>
                    <div>Available Space</div>
                </div>
                <div class="stat-card">
                    <div class="stat-number">$(echo "$ARCH_INFO" | cut -c1-3)</div>
                    <div>Architecture</div>
                </div>
            </div>
            <div class="grid">
                <div class="card">
                    <h3>🖥️ Operating System</h3>
                    <p><strong>OS:</strong> $OS_INFO</p>
                    <p><strong>Kernel:</strong> $KERNEL_INFO</p>
                    <p><strong>Architecture:</strong> $ARCH_INFO</p>
                </div>
                <div class="card">
                    <h3>⚡ Performance</h3>
                    <p><strong>Uptime:</strong> $UPTIME_INFO</p>
                    <p><strong>Load Average:</strong>$LOAD_AVG</p>
                    <p><strong>CPU Cores:</strong> $CPU_INFO</p>
                </div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🔧</span>Programming Languages & Runtimes</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status python3 "python3 --version")</div>
                <div class="tool-item">$(get_tool_status node "node --version")</div>
                <div class="tool-item">$(get_tool_status npm "npm --version")</div>
                <div class="tool-item">$(get_tool_status yarn "yarn --version")</div>
                <div class="tool-item">$(get_tool_status php "php --version | head -n1")</div>
                <div class="tool-item">$(get_tool_status composer "composer --version")</div>
                <div class="tool-item">$(get_tool_status java "java --version | head -n1")</div>
                <div class="tool-item">$(get_tool_status go "go version")</div>
                <div class="tool-item">$(get_tool_status rustc "rustc --version")</div>
                <div class="tool-item">$(get_tool_status ruby "ruby --version")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🗄️</span>Databases</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status mysql "mysql --version")</div>
                <div class="tool-item">$(get_tool_status psql "psql --version")</div>
                <div class="tool-item">$(get_tool_status sqlite3 "sqlite3 --version")</div>
                <div class="tool-item">$(get_tool_status redis-server "redis-server --version")</div>
                <div class="tool-item">$(get_tool_status mongod "mongod --version | head -n1")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🌐</span>Web Servers & Proxies</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status nginx "nginx -v 2>&1")</div>
                <div class="tool-item">$(get_tool_status apache2 "apache2 -v | head -n1")</div>
                <div class="tool-item">$(get_tool_status caddy "caddy version")</div>
                <div class="tool-item">$(get_tool_status haproxy "haproxy -v | head -n1")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🐳</span>Containerization & Orchestration</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status docker "docker --version")</div>
                <div class="tool-item">$(get_tool_status docker-compose "docker-compose --version")</div>
                <div class="tool-item">$(get_tool_status kubectl "kubectl version --client --short 2>/dev/null")</div>
                <div class="tool-item">$(get_tool_status minikube "minikube version --short")</div>
                <div class="tool-item">$(get_tool_status helm "helm version --short")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">☁️</span>Cloud & DevOps Tools</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status terraform "terraform version | head -n1")</div>
                <div class="tool-item">$(get_tool_status ansible "ansible --version | head -n1")</div>
                <div class="tool-item">$(get_tool_status aws "aws --version")</div>
                <div class="tool-item">$(get_tool_status gcloud "gcloud version --format='value(Google Cloud SDK)' 2>/dev/null")</div>
                <div class="tool-item">$(get_tool_status az "az --version | head -n1")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🛠️</span>Development Tools</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status git "git --version")</div>
                <div class="tool-item">$(get_tool_status code "echo 'Visual Studio Code'")</div>
                <div class="tool-item">$(get_tool_status vim "vim --version | head -n1")</div>
                <div class="tool-item">$(get_tool_status tmux "tmux -V")</div>
                <div class="tool-item">$(get_tool_status fzf "echo 'Fuzzy Finder'")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">🔒</span>Security Tools</h2>
            <div class="tool-list">
                <div class="tool-item">$(get_tool_status ufw "echo 'UFW Firewall'")</div>
                <div class="tool-item">$(get_tool_status fail2ban-server "echo 'Fail2Ban'")</div>
                <div class="tool-item">$(get_tool_status clamscan "echo 'ClamAV Antivirus'")</div>
            </div>
        </section>

        <section class="section">
            <h2><span class="section-icon">📋</span>Useful Commands & Next Steps</h2>
            <div class="commands-grid">
                <div class="command-block">
                    <h4>🔄 Next Steps</h4>
                    <code>source ~/.bashrc</code>
                    <code>git config --global user.name "Your Name"</code>
                    <code>git config --global user.email "your.email@example.com"</code>
                    <code>sudo reboot</code>
                </div>
                <div class="command-block">
                    <h4>🐳 Docker Commands</h4>
                    <code>dps # List containers</code>
                    <code>dstop # Stop all containers</code>
                    <code>dclean # Clean system</code>
                </div>
                <div class="command-block">
                    <h4>📊 Monitoring</h4>
                    <code>htop # Process monitor</code>
                    <code>glances # System overview</code>
                    <code>neofetch # System info</code>
                    <code>logs # System logs</code>
                </div>
                <div class="command-block">
                    <h4>🔧 Git Shortcuts</h4>
                    <code>gs # git status</code>
                    <code>ga # git add</code>
                    <code>gc # git commit</code>
                    <code>gp # git push</code>
                </div>
            </div>
        </section>
    </div>

    <button class="floating-action" onclick="window.scrollTo(0,0)" title="Back to top">↑</button>

    <footer class="footer">
        <p>🎉 <strong>Congratulations!</strong> Your ultimate development environment is ready! 🚀</p>
        <p>Generated by Ultimate Development Tools Installation Script v2.1</p>
    </footer>

    <script>
        // Add smooth scrolling and animations
        document.addEventListener('DOMContentLoaded', function() {
            // Animate cards on scroll
            const observer = new IntersectionObserver((entries) => {
                entries.forEach((entry) => {
                    if (entry.isIntersecting) {
                        entry.target.style.opacity = '1';
                        entry.target.style.transform = 'translateY(0)';
                    }
                });
            });

            document.querySelectorAll('.section').forEach((section) => {
                section.style.opacity = '0';
                section.style.transform = 'translateY(20px)';
                section.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
                observer.observe(section);
            });
        });
    </script>
</body>
</html>
EOF

    # Generate text report as backup
    cat > "$REPORT_TXT" << EOF
SYSTEM SETUP REPORT
Generated on: $(date)
==================

SYSTEM INFORMATION:
- OS: $OS_INFO
- Kernel: $KERNEL_INFO
- Architecture: $ARCH_INFO
- Memory: $MEMORY_INFO
- CPU: $CPU_INFO cores
- Disk Space: $DISK_INFO available

INSTALLED DEVELOPMENT TOOLS:

PROGRAMMING LANGUAGES & RUNTIMES:
EOF

    # Check installed tools for text report
    command_exists python3 && echo "✓ Python $(python3 --version)" >> "$REPORT_TXT"
    command_exists node && echo "✓ Node.js $(node --version)" >> "$REPORT_TXT"
    command_exists npm && echo "✓ NPM $(npm --version)" >> "$REPORT_TXT"
    command_exists yarn && echo "✓ Yarn $(yarn --version)" >> "$REPORT_TXT"
    command_exists php && echo "✓ PHP $(php --version | head -n1)" >> "$REPORT_TXT"
    command_exists composer && echo "✓ Composer $(composer --version)" >> "$REPORT_TXT"
    command_exists java && echo "✓ Java $(java --version | head -n1)" >> "$REPORT_TXT"
    command_exists go && echo "✓ Go $(go version)" >> "$REPORT_TXT"
    command_exists rustc && echo "✓ Rust $(rustc --version)" >> "$REPORT_TXT"
    command_exists ruby && echo "✓ Ruby $(ruby --version)" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "DATABASES:" >> "$REPORT_TXT"
    command_exists mysql && echo "✓ MySQL/MariaDB $(mysql --version)" >> "$REPORT_TXT"
    command_exists psql && echo "✓ PostgreSQL $(psql --version)" >> "$REPORT_TXT"
    command_exists sqlite3 && echo "✓ SQLite $(sqlite3 --version)" >> "$REPORT_TXT"
    command_exists redis-server && echo "✓ Redis $(redis-server --version)" >> "$REPORT_TXT"
    command_exists mongod && echo "✓ MongoDB $(mongod --version | head -n1)" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "WEB SERVERS & PROXIES:" >> "$REPORT_TXT"
    command_exists nginx && echo "✓ Nginx $(nginx -v 2>&1)" >> "$REPORT_TXT"
    command_exists apache2 && echo "✓ Apache $(apache2 -v | head -n1)" >> "$REPORT_TXT"
    command_exists caddy && echo "✓ Caddy $(caddy version)" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "CONTAINERIZATION:" >> "$REPORT_TXT"
    command_exists docker && echo "✓ Docker $(docker --version)" >> "$REPORT_TXT"
    command_exists docker-compose && echo "✓ Docker Compose $(docker-compose --version)" >> "$REPORT_TXT"
    command_exists kubectl && echo "✓ kubectl $(kubectl version --client --short 2>/dev/null)" >> "$REPORT_TXT"
    command_exists minikube && echo "✓ Minikube $(minikube version --short)" >> "$REPORT_TXT"
    command_exists helm && echo "✓ Helm $(helm version --short)" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "CLOUD & DEVOPS:" >> "$REPORT_TXT"
    command_exists terraform && echo "✓ Terraform $(terraform version | head -n1)" >> "$REPORT_TXT"
    command_exists ansible && echo "✓ Ansible $(ansible --version | head -n1)" >> "$REPORT_TXT"
    command_exists aws && echo "✓ AWS CLI $(aws --version)" >> "$REPORT_TXT"
    command_exists gcloud && echo "✓ Google Cloud SDK $(gcloud version --format='value(Google Cloud SDK)' 2>/dev/null)" >> "$REPORT_TXT"
    command_exists az && echo "✓ Azure CLI $(az --version | head -n1)" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "DEVELOPMENT TOOLS:" >> "$REPORT_TXT"
    command_exists git && echo "✓ Git $(git --version)" >> "$REPORT_TXT"
    command_exists code && echo "✓ Visual Studio Code" >> "$REPORT_TXT"
    command_exists vim && echo "✓ Vim $(vim --version | head -n1)" >> "$REPORT_TXT"
    command_exists tmux && echo "✓ Tmux $(tmux -V)" >> "$REPORT_TXT"
    command_exists fzf && echo "✓ Fuzzy Finder" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "SECURITY TOOLS:" >> "$REPORT_TXT"
    command_exists ufw && echo "✓ UFW Firewall" >> "$REPORT_TXT"
    command_exists fail2ban-server && echo "✓ Fail2Ban" >> "$REPORT_TXT"
    command_exists clamscan && echo "✓ ClamAV" >> "$REPORT_TXT"
    
    echo "" >> "$REPORT_TXT"
    echo "USEFUL COMMANDS & NEXT STEPS:" >> "$REPORT_TXT"
    cat >> "$REPORT_TXT" << 'EOF'

NEXT STEPS:
1. Reload your shell: source ~/.bashrc
2. Configure Git: git config --global user.name "Your Name"
3. Configure Git: git config --global user.email "your.email@example.com"
4. Log out and log back in to apply group changes (especially for Docker)
5. Review and configure installed services as needed

USEFUL COMMANDS:
- System monitoring: htop, glances, neofetch
- Network tools: nmap, netstat, ss
- File operations: tree, fd, rg, bat
- Docker: dps, dstop, dclean (custom aliases)
- Git: gs, ga, gc, gp (custom aliases)
- Development: code (VS Code), vim, tmux

SECURITY RECOMMENDATIONS:
- Review UFW firewall rules: sudo ufw status
- Configure Fail2Ban: sudo systemctl status fail2ban
- Update regularly: update (custom alias)
- Monitor logs: logs (custom alias)

For more information, check the documentation of individual tools.
EOF
    
    info "Reports generated:"
    info "📊 HTML Report: $REPORT_HTML"
    info "📄 Text Report: $REPORT_TXT"
    
    # Try to open HTML report in browser
    if command_exists xdg-open; then
        log "Opening HTML report in browser..."
        xdg-open "$REPORT_HTML" 2>/dev/null &
    elif command_exists firefox; then
        firefox "$REPORT_HTML" 2>/dev/null &
    elif command_exists chromium-browser; then
        chromium-browser "$REPORT_HTML" 2>/dev/null &
    fi
}

# Main installation function
main() {
    log "=== STARTING ULTIMATE DEVELOPMENT ENVIRONMENT SETUP ==="
    echo -e "${PURPLE}This script will install a comprehensive development environment.${NC}"
    echo -e "${PURPLE}The installation may take 30-60 minutes depending on your internet speed.${NC}"
    echo ""
    
    # Confirm installation
    read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled by user."
        exit 0
    fi
    
    # Run installation steps
    print_system_info
    update_system
    install_essential_tools
    install_network_security_tools
    install_programming_languages
    install_databases
    install_web_servers
    install_containerization
    install_cloud_devops
    install_monitoring_logging
    install_dev_tools
    install_media_graphics
    install_system_monitoring
    install_security_tools
    install_backup_sync
    install_communication
    install_future_tools
    configure_services
    create_aliases
    optimize_system
    cleanup_installation
    generate_report
    
    log "=== INSTALLATION COMPLETED SUCCESSFULLY! ==="
    echo -e "${GREEN}Your development environment is now ready!${NC}"
    echo -e "${YELLOW}Please review the installation report and follow the next steps.${NC}"
    echo -e "${CYAN}Don't forget to log out and log back in to apply all changes.${NC}"
    echo ""
    echo -e "${PURPLE}Installation report: $(ls -t "$HOME"/system_setup_report_*.txt | head -n1)${NC}"
    
    # Show summary
    echo ""
    log "=== INSTALLATION SUMMARY ==="
    info "✓ System updated and optimized"
    info "✓ Essential development tools installed"
    info "✓ Programming languages and runtimes configured"
    info "✓ Databases and web servers ready"
    info "✓ Containerization tools available"
    info "✓ Cloud and DevOps tools installed"
    info "✓ Security tools configured"
    info "✓ Future-proof technologies prepared"
    info "✓ Useful aliases and functions added"
    info "✓ System optimizations applied"
    
    echo ""
    warning "IMPORTANT: Please reboot your system or log out and log back in to ensure all changes take effect."
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
