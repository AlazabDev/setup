#!/bin/bash

# =============================================================================
# Al-Azab Construction Company ERP Deployment Script
# Professional automated deployment script for erp.alazab.com
# =============================================================================

set -e  # Exit on any error

# Configuration
SITE_NAME="erp.alazab.com"
DB_PASSWORD="azab123"
BENCH_USER=$(whoami)
BENCH_PATH="/home/$BENCH_USER/frappe-bench"
LOG_FILE="/tmp/alazab_erp_deployment.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

error_log() {
    echo -e "${RED}[ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

warning_log() {
    echo -e "${YELLOW}[WARNING] [$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

info_log() {
    echo -e "${BLUE}[INFO] [$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

# Error handling function
handle_error() {
    local app_name="$1"
    local error_msg="$2"
    error_log "Failed to install $app_name: $error_msg"
    echo "$app_name:FAILED:$error_msg" >> /tmp/failed_apps.log
    warning_log "Continuing with next application..."
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists "bench"; then
        missing_tools+=("bench")
    fi
    
    if ! command_exists "git"; then
        missing_tools+=("git")
    fi
    
    if ! command_exists "python3"; then
        missing_tools+=("python3")
    fi
    
    if ! command_exists "node"; then
        missing_tools+=("node")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error_log "Missing required tools: ${missing_tools[*]}"
        error_log "Please install missing tools before running this script"
        exit 1
    fi
    
    log "All prerequisites are satisfied"
}

# Create bench if doesn't exist
setup_bench() {
    log "Setting up Frappe bench..."
    
    if [ ! -d "$BENCH_PATH" ]; then
        log "Creating new bench at $BENCH_PATH"
        bench init frappe-bench --frappe-branch version-15
        cd $BENCH_PATH
    else
        log "Bench already exists at $BENCH_PATH"
        cd $BENCH_PATH
    fi
    
    # Update bench
    log "Updating bench..."
    bench update --reset || warning_log "Bench update failed, continuing..."
}

# Create site if doesn't exist
setup_site() {
    log "Setting up site: $SITE_NAME"
    
    cd $BENCH_PATH
    
    if bench --site $SITE_NAME list-apps >/dev/null 2>&1; then
        log "Site $SITE_NAME already exists"
    else
        log "Creating new site: $SITE_NAME"
        bench new-site $SITE_NAME --admin-password admin --mariadb-root-password $DB_PASSWORD
    fi
}

# Install application with error handling
install_app() {
    local app_name="$1"
    local repo_url="$2"
    local branch="${3:-version-15}"
    
    log "Installing application: $app_name"
    
    cd $BENCH_PATH
    
    # Check if app is already installed
    if [ -d "apps/$app_name" ]; then
        warning_log "App $app_name already exists, pulling latest changes..."
        cd apps/$app_name
        git pull origin $branch || warning_log "Failed to pull latest changes for $app_name"
        cd $BENCH_PATH
    else
        # Get the app
        if ! bench get-app $repo_url --branch $branch; then
            handle_error "$app_name" "Failed to get app from repository"
            return 1
        fi
    fi
    
    # Install app on site
    if ! bench --site $SITE_NAME install-app $app_name; then
        handle_error "$app_name" "Failed to install app on site"
        return 1
    fi
    
    log "Successfully installed: $app_name"
    return 0
}

# Main installation function
install_applications() {
    log "Starting application installation process..."
    
    # Initialize failed apps log
    > /tmp/failed_apps.log
    
    # Core applications (ERPNext and dependencies)
    install_app "erpnext" "https://github.com/frappe/erpnext"
    install_app "hrms" "https://github.com/frappe/hrms"
    
    # CRM and Customer Management
    install_app "crm" "https://github.com/frappe/crm"
    install_app "helpdesk" "https://github.com/frappe/helpdesk"
    
    # File Management and Analytics
    install_app "drive" "https://github.com/frappe/drive"
    install_app "insights" "https://github.com/frappe/insights"
    
    # Development and Customization Tools
    install_app "studio" "https://github.com/frappe/frappe_ui" "main"
    install_app "builder" "https://github.com/frappe/builder"
    
    # Charts and Visualization
    install_app "charts" "https://github.com/frappe/charts"
    
    # E-commerce and Payments
    install_app "webshop" "https://github.com/frappe/webshop"
    install_app "payments" "https://github.com/frappe/payments"
    
    # Communication and Marketing
    install_app "newsletter" "https://github.com/frappe/newsletter"
    install_app "waba_integration" "https://github.com/frappe/waba_integration"
    
    # Project Management
    install_app "gameplan" "https://github.com/frappe/gameplan"
    install_app "gantt" "https://github.com/frappe/gantt"
    
    # Specialized Applications
    install_app "print_designer" "https://github.com/frappe/print_designer"
    install_app "ecommerce_integrations" "https://github.com/frappe/ecommerce_integrations"
    
    # Egypt Compliance (Custom Repository)
    log "Installing Egypt Compliance from AlazabDev repository..."
    install_app "erpnext_egypt_compliance" "https://github.com/AlazabDev/erpnext_egypt_compliance"
    
    # Optional/Additional Apps
    install_app "translator" "https://github.com/frappe/translator"
    
    # Try to install books if available
    install_app "books" "https://github.com/frappe/books" "main" || warning_log "Books app installation failed, skipping..."
    
    log "Application installation process completed"
}

# Build and migrate
build_and_migrate() {
    log "Building assets and migrating database..."
    
    cd $BENCH_PATH
    
    # Build assets
    log "Building assets..."
    if ! bench build; then
        error_log "Asset build failed"
        return 1
    fi
    
    # Migrate database
    log "Migrating database..."
    if ! bench --site $SITE_NAME migrate; then
        error_log "Database migration failed"
        return 1
    fi
    
    # Clear cache
    log "Clearing cache..."
    bench --site $SITE_NAME clear-cache
    bench --site $SITE_NAME clear-website-cache
    
    log "Build and migration completed successfully"
}

# Configure production settings
configure_production() {
    log "Configuring production settings..."
    
    cd $BENCH_PATH
    
    # Setup production config
    bench --site $SITE_NAME enable-scheduler
    bench --site $SITE_NAME set-maintenance-mode off
    
    # Setup SSL if not already configured
    if command_exists "certbot"; then
        log "Setting up SSL certificate..."
        bench setup lets-encrypt $SITE_NAME || warning_log "SSL setup failed, continuing..."
    fi
    
    # Setup production
    if command_exists "supervisorctl"; then
        log "Setting up production environment..."
        sudo bench setup production $BENCH_USER || warning_log "Production setup failed, continuing..."
    fi
    
    log "Production configuration completed"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    cd $BENCH_PATH
    
    # List installed apps
    log "Installed applications:"
    bench --site $SITE_NAME list-apps
    
    # Check site status
    if bench --site $SITE_NAME doctor; then
        log "Site health check passed"
    else
        warning_log "Site health check failed"
    fi
    
    # Test site access
    log "Testing site access..."
    if curl -s -o /dev/null -w "%{http_code}" http://$SITE_NAME | grep -q "200\|302"; then
        log "Site is accessible"
    else
        warning_log "Site access test failed"
    fi
}

# Generate installation report
generate_report() {
    log "Generating installation report..."
    
    local report_file="/tmp/alazab_erp_installation_report.txt"
    
    cat > $report_file << EOF
=============================================================================
Al-Azab Construction Company ERP Installation Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Site: $SITE_NAME
=============================================================================

INSTALLATION SUMMARY:
- Bench Path: $BENCH_PATH
- Site Name: $SITE_NAME
- Log File: $LOG_FILE

INSTALLED APPLICATIONS:
$(cd $BENCH_PATH && bench --site $SITE_NAME list-apps 2>/dev/null || echo "Could not retrieve app list")

FAILED APPLICATIONS:
$(if [ -f /tmp/failed_apps.log ] && [ -s /tmp/failed_apps.log ]; then cat /tmp/failed_apps.log; else echo "None"; fi)

NEXT STEPS:
1. Access your ERP system at: https://$SITE_NAME
2. Login with:
   - Username: Administrator
   - Password: admin (Please change immediately)
3. Review any failed applications and install manually if needed
4. Configure system settings according to your business requirements

USEFUL COMMANDS:
- Start/Stop: bench start / bench restart
- Update: bench update
- Backup: bench --site $SITE_NAME backup
- Clear Cache: bench --site $SITE_NAME clear-cache

=============================================================================
EOF

    log "Installation report generated: $report_file"
    cat $report_file
}

# Cleanup function
cleanup() {
    log "Performing cleanup..."
    
    cd $BENCH_PATH
    
    # Remove temporary files
    rm -f /tmp/failed_apps.log
    
    # Restart services
    if command_exists "supervisorctl"; then
        sudo supervisorctl restart all || warning_log "Failed to restart services"
    else
        bench restart || warning_log "Failed to restart bench"
    fi
    
    log "Cleanup completed"
}

# Main execution function
main() {
    log "Starting Al-Azab Construction ERP deployment..."
    log "Target site: $SITE_NAME"
    log "Log file: $LOG_FILE"
    
    # Initialize log file
    > $LOG_FILE
    
    # Check prerequisites
    check_prerequisites
    
    # Setup bench and site
    setup_bench
    setup_site
    
    # Install applications
    install_applications
    
    # Build and migrate
    build_and_migrate
    
    # Configure production
    configure_production
    
    # Verify installation
    verify_installation
    
    # Generate report
    generate_report
    
    # Cleanup
    cleanup
    
    log "Al-Azab Construction ERP deployment completed!"
    log "Access your system at: https://$SITE_NAME"
    
    # Show failed apps if any
    if [ -f /tmp/failed_apps.log ] && [ -s /tmp/failed_apps.log ]; then
        warning_log "Some applications failed to install. Check the report for details."
        warning_log "You can manually install failed apps later using:"
        warning_log "bench get-app <app_url> && bench --site $SITE_NAME install-app <app_name>"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
