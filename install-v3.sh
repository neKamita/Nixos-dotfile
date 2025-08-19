#!/usr/bin/env bash

# XNM1 Hyprland installer for NixOS (ASCII only version)
# Version 3.0 - no cyrillic characters

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "     XNM1 Hyprland Auto Installer v3.0"
    echo "           for NixOS system"
    echo "=============================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[STEP] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_nixos() {
    if [[ ! -f /etc/nixos/configuration.nix ]]; then
        print_error "This script works only on NixOS!"
        exit 1
    fi
    print_step "NixOS check - OK"
}

get_user_input() {
    echo
    echo -e "${YELLOW}Please enter system configuration data:${NC}"
    echo
    
    # Username
    while true; do
        read -p "Enter your username (current: $USER): " USERNAME
        USERNAME=${USERNAME:-$USER}
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            break
        else
            print_error "Invalid username. Use only letters, numbers, _ and -"
        fi
    done
    
    # Hostname
    while true; do
        read -p "Enter computer hostname: " HOSTNAME
        if [[ -n "$HOSTNAME" && "$HOSTNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            print_error "Invalid hostname. Use only letters, numbers and -"
        fi
    done
    
    echo
    echo -e "${BLUE}Selected settings:${NC}"
    echo "  User: $USERNAME"
    echo "  Host: $HOSTNAME"
    echo
}

confirm_installation() {
    print_warning "This script will make changes to your system!"
    print_warning "USBGuard will be disabled to avoid problems"
    print_warning "Current configs will be backed up"
    
    echo
    read -p "Continue installation? (type 'yes' to continue): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Installation cancelled by user."
        exit 0
    fi
}

install_fonts_first() {
    print_step "Installing FULL font support for proper display..."
    
    # Add comprehensive fonts to current configuration
    if ! grep -q "dejavu_fonts" /etc/nixos/configuration.nix 2>/dev/null; then
        print_step "Adding comprehensive fonts support to system..."
        
        sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.fonts.$(date +%Y%m%d_%H%M%S)
        
        sudo tee -a /etc/nixos/configuration.nix > /dev/null << 'FONTSEOF'

# COMPREHENSIVE font support
fonts = {
  packages = with pkgs; [
    # Core fonts
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    noto-fonts-extra
    
    # Google fonts
    google-fonts
    
    # Monospace fonts
    source-code-pro
    fira-code
    jetbrains-mono
    
    # Terminal fonts
    terminus_font
    inconsolata
    
    # System fonts
    font-awesome
    powerline-fonts
    
    # Unicode fonts
    unifont
    symbola
    
    # Microsoft fonts (optional)
    corefonts
    vistafonts
  ];
  
  # Font rendering configuration
  fontconfig = {
    defaultFonts = {
      serif = [ "DejaVu Serif" "Noto Serif" ];
      sansSerif = [ "DejaVu Sans" "Noto Sans" ];
      monospace = [ "DejaVu Sans Mono" "Noto Sans Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
    
    enable = true;
    antialias = true;
    hinting.enable = true;
    hinting.style = "slight";
    subpixel.rgba = "rgb";
  };
};

# Full localization support
i18n = {
  defaultLocale = "en_US.UTF-8";
  supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ru_RU.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];
  extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };
};

# Console with Unicode support
console = {
  font = "ter-u28n";
  packages = [ pkgs.terminus_font ];
  keyMap = "us";
  useXkbConfig = true;
};
FONTSEOF
        
        print_step "Applying comprehensive font changes..."
        sudo nixos-rebuild switch
        
        print_step "Full font support installed. All text should display correctly now."
    else
        echo "  Fonts already configured"
    fi
}

install_git() {
    if ! command -v git &> /dev/null; then
        print_step "Installing git..."
        nix-shell -p git --run "echo Git available"
    fi
}

clone_repo() {
    print_step "Cloning XNM1 repository..."
    
    if [[ -d "linux-nixos-hyprland-config-dotfiles" ]]; then
        print_warning "Directory already exists, removing..."
        rm -rf linux-nixos-hyprland-config-dotfiles
    fi
    
    nix-shell -p git --run "git clone https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles.git"
    cd linux-nixos-hyprland-config-dotfiles
}

configure_system() {
    print_step "Configuring system for your setup..."
    
    # Replace username
    echo "  - Replacing user 'xnm' with '$USERNAME'"
    find . -type f -name "*.nix" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.conf" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.toml" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    
    # Replace hostname
    echo "  - Replacing host 'isitreal-laptop' with '$HOSTNAME'"
    find . -type f -name "*.nix" -exec sed -i "s/isitreal-laptop/$HOSTNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.conf" -exec sed -i "s/isitreal-laptop/$HOSTNAME/g" {} + 2>/dev/null || true
    
    # Disable USBGuard
    echo "  - Disabling USBGuard for safety"
    cat > nixos/usb.nix << 'USBEOF'
{ config, pkgs, ... }:

{
  # USBGuard disabled for easier installation
  # You can configure it later if needed
  services.usbguard.enable = false;
  
  # Basic USB device support
  hardware.enableRedistributableFirmware = true;
  
  # Support for most USB devices
  services.udisks2.enable = true;
}
USBEOF

    # Clean personal git settings
    echo "  - Cleaning personal settings"
    if [[ -f "home/.gitconfig" ]]; then
        cat > home/.gitconfig << GITEOF
[user]
    name = $USERNAME
    email = $USERNAME@localhost
    
[init]
    defaultBranch = main
    
[core]
    editor = nano
GITEOF
    fi
    
    # Clean SSH config
    if [[ -f "home/.ssh/config" ]]; then
        echo "# SSH configuration" > home/.ssh/config
        echo "# Add your settings here" >> home/.ssh/config
    fi
}

enable_flakes() {
    print_step "Checking Flakes support..."
    
    if ! grep -q "experimental-features.*flakes" /etc/nixos/configuration.nix 2>/dev/null; then
        print_step "Enabling Flakes support in system..."
        
        # Create backup
        sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.$(date +%Y%m%d_%H%M%S)
        
        # Add flakes support
        sudo tee -a /etc/nixos/configuration.nix > /dev/null << 'FLAKESEOF'

# Experimental Nix features support
nix.settings.experimental-features = [ "nix-command" "flakes" ];
FLAKESEOF
        
        print_step "Applying Flakes changes..."
        sudo nixos-rebuild switch
    else
        echo "  Flakes already enabled"
    fi
}

backup_configs() {
    print_step "Creating backups..."
    
    # Backup system files
    if [[ -f /etc/nixos/configuration.nix ]]; then
        sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.xnm1.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Backup user files (if exist)
    if [[ -f ~/.config/hypr/hyprland.conf ]]; then
        mkdir -p ~/.config.backup.xnm1
        cp -r ~/.config ~/.config.backup.xnm1/ 2>/dev/null || true
    fi
}

copy_files() {
    print_step "Copying configuration files..."
    
    # Copy user files
    echo "  - Copying user settings to $HOME"
    cp -r home/* ~/
    
    # Create necessary directories
    mkdir -p ~/.config ~/.local/share
    
    # Copy system files
    echo "  - Copying system files to /etc/nixos"
    sudo cp -r nixos/* /etc/nixos/
    
    # Set proper permissions
    echo "  - Setting permissions"
    sudo chown -R root:root /etc/nixos
    sudo chmod -R 644 /etc/nixos/*.nix
    sudo chmod 755 /etc/nixos
}

install_system() {
    print_step "Installing system... (this may take 10-30 minutes)"
    print_warning "Do not interrupt the installation process!"
    
    echo "  - Updating flake..."
    sudo nix flake update --flake /etc/nixos
    
    echo "  - Rebuilding system with new configuration..."
    if sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --upgrade; then
        print_step "System successfully installed!"
        return 0
    else
        print_error "Error during system rebuild"
        echo
        echo "Try running manually with detailed output:"
        echo "sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --show-trace"
        return 1
    fi
}

show_completion_info() {
    echo
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}           INSTALLATION COMPLETED!${NC}"
    echo -e "${GREEN}=============================================${NC}"
    echo
    echo -e "${BLUE}What to do next:${NC}"
    echo "   1. Reboot system: sudo reboot"
    echo "   2. After boot login with your user"
    echo "   3. Hyprland will start automatically"
    echo
    echo -e "${BLUE}Main hotkeys:${NC}"
    echo "   SUPER + D           - Launch apps (rofi)"
    echo "   SUPER + T           - Terminal"
    echo "   SUPER + B           - Browser"
    echo "   SUPER + F           - File manager"
    echo "   SUPER + SHIFT + Q   - Close window"
    echo "   SUPER + SHIFT + K   - Show all keys"
    echo
    echo -e "${BLUE}Useful terminal commands:${NC}"
    echo "   nswitch   - Rebuild system"
    echo "   nswitchu  - Update and rebuild"
    echo "   ngc       - Clean old versions"
    echo
    echo -e "${YELLOW}More information:${NC}"
    echo "   - Configuration: ~/.config/hypr/hyprland.conf"
    echo "   - System settings: /etc/nixos/"
    echo "   - GitHub: https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles"
    echo
}

# Main function
main() {
    print_header
    
    check_nixos
    install_fonts_first  # Install fonts FIRST
    get_user_input  
    confirm_installation
    
    install_git
    clone_repo
    configure_system
    enable_flakes
    backup_configs
    copy_files
    
    if install_system; then
        show_completion_info
        echo -e "${GREEN}Reboot system to complete installation!${NC}"
    else
        print_error "Installation failed. Check logs above."
        exit 1
    fi
}

# Signal handling
trap 'print_error "Installation interrupted by user"; exit 1' INT TERM

# Run
main "$@"
