#!/usr/bin/env bash

# Упрощенный установщик XNM1 Hyprland для NixOS
# Версия 2.0 - исправлены проблемы совместимости

set -e  # Остановка при ошибке

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              XNM1 Hyprland Auto Installer v2.0              ║"
    echo "║                    для NixOS системы                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[ШАГ] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[ВНИМАНИЕ] $1${NC}"
}

print_error() {
    echo -e "${RED}[ОШИБКА] $1${NC}"
}

check_nixos() {
    if [[ ! -f /etc/nixos/configuration.nix ]]; then
        print_error "Этот скрипт работает только на NixOS!"
        exit 1
    fi
    print_step "Проверка NixOS - ОК"
}

get_user_input() {
    echo
    echo -e "${YELLOW}Необходимо ввести данные для настройки системы:${NC}"
    echo
    
    # Имя пользователя
    while true; do
        read -p "Введите ваше имя пользователя (текущий: $USER): " USERNAME
        USERNAME=${USERNAME:-$USER}
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            break
        else
            print_error "Неверное имя пользователя. Используйте только буквы, цифры, _ и -"
        fi
    done
    
    # Hostname
    while true; do
        read -p "Введите имя компьютера (hostname): " HOSTNAME
        if [[ -n "$HOSTNAME" && "$HOSTNAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
            break
        else
            print_error "Неверное имя хоста. Используйте только буквы, цифры и -"
        fi
    done
    
    echo
    echo -e "${BLUE}Выбранные настройки:${NC}"
    echo "  Пользователь: $USERNAME"
    echo "  Хост: $HOSTNAME"
    echo
}

confirm_installation() {
    print_warning "Этот скрипт внесет изменения в вашу систему!"
    print_warning "USBGuard будет отключен для избежания проблем"
    print_warning "Текущие конфигурации будут сохранены как backup"
    
    echo
    read -p "Продолжить установку? (введите 'yes' для продолжения): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Установка отменена пользователем."
        exit 0
    fi
}

install_git() {
    if ! command -v git &> /dev/null; then
        print_step "Установка git..."
        nix-shell -p git --run "echo Git доступен"
    fi
}

clone_repo() {
    print_step "Клонирование репозитория XNM1..."
    
    if [[ -d "linux-nixos-hyprland-config-dotfiles" ]]; then
        print_warning "Папка уже существует, удаляем..."
        rm -rf linux-nixos-hyprland-config-dotfiles
    fi
    
    nix-shell -p git --run "git clone https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles.git"
    cd linux-nixos-hyprland-config-dotfiles
}

configure_system() {
    print_step "Настройка конфигурации под вашу систему..."
    
    # Замена имени пользователя
    echo "  - Замена пользователя 'xnm' на '$USERNAME'"
    find . -type f -name "*.nix" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.conf" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.toml" -exec sed -i "s/xnm/$USERNAME/g" {} + 2>/dev/null || true
    
    # Замена hostname
    echo "  - Замена хоста 'isitreal-laptop' на '$HOSTNAME'"
    find . -type f -name "*.nix" -exec sed -i "s/isitreal-laptop/$HOSTNAME/g" {} + 2>/dev/null || true
    find . -type f -name "*.conf" -exec sed -i "s/isitreal-laptop/$HOSTNAME/g" {} + 2>/dev/null || true
    
    # Отключение USBGuard
    echo "  - Отключение USBGuard для безопасности"
    cat > nixos/usb.nix << 'USBEOF'
{ config, pkgs, ... }:

{
  # USBGuard отключен для упрощения установки
  # При необходимости можете настроить позже
  services.usbguard.enable = false;
  
  # Базовая поддержка USB устройств
  hardware.enableRedistributableFirmware = true;
  
  # Поддержка большинства USB устройств
  services.udisks2.enable = true;
}
USBEOF

    # Очистка персональных настроек git
    echo "  - Очистка персональных настроек"
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
    
    # Очистка SSH конфига
    if [[ -f "home/.ssh/config" ]]; then
        echo "# SSH конфигурация" > home/.ssh/config
        echo "# Добавьте ваши настройки здесь" >> home/.ssh/config
    fi
}

enable_flakes() {
    print_step "Проверка поддержки Flakes..."
    
    if ! grep -q "experimental-features.*flakes" /etc/nixos/configuration.nix 2>/dev/null; then
        print_step "Включение поддержки Flakes в системе..."
        
        # Создаем backup
        sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.$(date +%Y%m%d_%H%M%S)
        
        # Добавляем поддержку flakes
        sudo tee -a /etc/nixos/configuration.nix > /dev/null << 'FLAKESEOF'

# Поддержка экспериментальных возможностей Nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
FLAKESEOF
        
        print_step "Применение изменений для Flakes..."
        sudo nixos-rebuild switch
    else
        echo "  Flakes уже включены"
    fi
}

backup_configs() {
    print_step "Создание резервных копий..."
    
    # Backup системных файлов
    if [[ -f /etc/nixos/configuration.nix ]]; then
        sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.xnm1.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Backup пользовательских файлов (если есть)
    if [[ -f ~/.config/hypr/hyprland.conf ]]; then
        mkdir -p ~/.config.backup.xnm1
        cp -r ~/.config ~/.config.backup.xnm1/ 2>/dev/null || true
    fi
}

copy_files() {
    print_step "Копирование конфигурационных файлов..."
    
    # Копирование пользовательских файлов
    echo "  - Копирование пользовательских настроек в $HOME"
    cp -r home/* ~/
    
    # Создание необходимых директорий
    mkdir -p ~/.config ~/.local/share
    
    # Копирование системных файлов
    echo "  - Копирование системных файлов в /etc/nixos"
    sudo cp -r nixos/* /etc/nixos/
    
    # Установка правильных прав доступа
    echo "  - Установка прав доступа"
    sudo chown -R root:root /etc/nixos
    sudo chmod -R 644 /etc/nixos/*.nix
    sudo chmod 755 /etc/nixos
}

install_system() {
    print_step "Установка системы... (это может занять 10-30 минут)"
    print_warning "Не прерывайте процесс установки!"
    
    echo "  - Обновление flake..."
    sudo nix flake update --flake /etc/nixos
    
    echo "  - Пересборка системы с новой конфигурацией..."
    if sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --upgrade; then
        print_step "✅ Система успешно установлена!"
        return 0
    else
        print_error "Ошибка при пересборке системы"
        echo
        echo "Попробуйте запустить вручную с подробным выводом:"
        echo "sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --show-trace"
        return 1
    fi
}

show_completion_info() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    УСТАНОВКА ЗАВЕРШЕНА!                     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BLUE}🎉 Что делать дальше:${NC}"
    echo "   1. Перезагрузите систему: sudo reboot"
    echo "   2. После загрузки войдите под своим пользователем"
    echo "   3. Hyprland запустится автоматически"
    echo
    echo -e "${BLUE}📋 Основные горячие клавиши:${NC}"
    echo "   SUPER + D           - Запуск приложений (rofi)"
    echo "   SUPER + T           - Терминал"
    echo "   SUPER + B           - Браузер"
    echo "   SUPER + F           - Файловый менеджер"
    echo "   SUPER + SHIFT + Q   - Закрыть окно"
    echo "   SUPER + SHIFT + K   - Показать все клавиши"
    echo
    echo -e "${BLUE}🔧 Полезные команды в терминале:${NC}"
    echo "   nswitch   - Пересобрать систему"
    echo "   nswitchu  - Обновить и пересобрать"
    echo "   ngc       - Очистить старые версии"
    echo
    echo -e "${YELLOW}📚 Больше информации:${NC}"
    echo "   - Конфигурация: ~/.config/hypr/hyprland.conf"
    echo "   - Системные настройки: /etc/nixos/"
    echo "   - GitHub: https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles"
    echo
}

# Основная функция
main() {
    print_header
    
    check_nixos
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
        echo -e "${GREEN}Перезагрузите систему для завершения установки!${NC}"
    else
        print_error "Установка не удалась. Проверьте логи выше."
        exit 1
    fi
}

# Обработка сигналов
trap 'print_error "Установка прервана пользователем"; exit 1' INT TERM

# Запуск
main "$@"
