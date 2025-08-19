#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Автоматический установщик XNM1 Hyprland для NixOS${NC}"
echo "=================================================="

# Проверка что мы в NixOS
if [[ ! -f /etc/nixos/configuration.nix ]]; then
    echo -e "${RED}❌ Этот скрипт работает только на NixOS!${NC}"
    exit 1
fi

# Запрос данных пользователя
echo -e "${YELLOW}📝 Пожалуйста, введите следующую информацию:${NC}"
read -p "Ваше имя пользователя (текущее: $USER): " USERNAME
USERNAME=${USERNAME:-$USER}

read -p "Имя хоста (hostname) системы: " HOSTNAME
if [[ -z "$HOSTNAME" ]]; then
    echo -e "${RED}❌ Имя хоста обязательно!${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  Внимание: USBGuard будет отключен для избежания проблем${NC}"
read -p "Продолжить? (y/N): " CONTINUE
if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo "Установка отменена."
    exit 1
fi

echo -e "${GREEN}📦 Клонирование репозитория...${NC}"
if [[ -d "linux-nixos-hyprland-config-dotfiles" ]]; then
    echo -e "${YELLOW}Папка уже существует. Удаляем...${NC}"
    rm -rf linux-nixos-hyprland-config-dotfiles
fi

git clone https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles.git
cd linux-nixos-hyprland-config-dotfiles

echo -e "${GREEN}🔧 Настройка конфигурации...${NC}"

# Функция для замены строк в файлах
replace_in_files() {
    local old="$1"
    local new="$2"
    echo "  Замена '$old' на '$new'..."
    
    # Поиск и замена в .nix файлах
    find . -name "*.nix" -type f -exec sed -i "s/$old/$new/g" {} +
    # В конфигурационных файлах
    find . -name "*.conf" -type f -exec sed -i "s/$old/$new/g" {} +
    # В прочих файлах
    find . -name "*.toml" -type f -exec sed -i "s/$old/$new/g" {} +
    find . -name "*.yaml" -type f -exec sed -i "s/$old/$new/g" {} +
}

# Замена имени пользователя и хоста
replace_in_files "xnm" "$USERNAME"
replace_in_files "isitreal-laptop" "$HOSTNAME"

echo -e "${GREEN}🔒 Отключение USBGuard...${NC}"
# Создаем простую конфигурацию USBGuard с отключением
cat > nixos/usb.nix << EOF
{ config, pkgs, ... }:

{
  # USBGuard отключен для упрощения установки
  services.usbguard.enable = false;
  
  # Базовая поддержка USB
  hardware.enableRedistributableFirmware = true;
}
EOF

echo -e "${GREEN}⚙️  Удаление личных настроек автора...${NC}"
# Очистка git конфигураций
if [[ -f "home/.gitconfig" ]]; then
    cat > home/.gitconfig << EOF
[user]
    name = $USERNAME
    email = $USERNAME@example.com

[init]
    defaultBranch = main
EOF
fi

# Очистка SSH конфига
if [[ -f "home/.ssh/config" ]]; then
    echo "# Добавьте ваши SSH настройки здесь" > home/.ssh/config
fi

echo -e "${GREEN}🔄 Включение flakes...${NC}"
# Проверяем, включены ли flakes
if ! grep -q "experimental-features.*flakes" /etc/nixos/configuration.nix; then
    echo "  Добавление поддержки flakes в систему..."
    sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup
    
    # Добавляем поддержку flakes
    sudo tee -a /etc/nixos/configuration.nix > /dev/null << EOF

# Поддержка flakes
nix.settings.experimental-features = [ "nix-command" "flakes" ];
EOF
    
    echo "  Применение изменений для flakes..."
    sudo nixos-rebuild switch
fi

echo -e "${GREEN}📂 Копирование файлов...${NC}"
# Создаем бэкапы
if [[ -f "/etc/nixos/configuration.nix" ]]; then
    sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup.$(date +%Y%m%d_%H%M%S)
fi

# Копируем файлы
echo "  Копирование пользовательских файлов..."
cp -r home/* ~/

echo "  Копирование системных файлов..."
sudo cp -r nixos/* /etc/nixos/

echo "  Установка правильных прав..."
sudo chown -R root:root /etc/nixos

echo -e "${GREEN}🚀 Запуск установки системы...${NC}"
echo -e "${YELLOW}Это может занять несколько минут...${NC}"

# Обновление и установка
sudo nix flake update --flake /etc/nixos
if sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --upgrade; then
    echo -e "${GREEN}✅ Установка завершена успешно!${NC}"
    echo ""
    echo "🎉 Перезагрузите систему для полного применения изменений:"
    echo "   sudo reboot"
    echo ""
    echo "📖 После перезагрузки используйте горячие клавиши:"
    echo "   SUPER + D - запуск rofi"
    echo "   SUPER + T - терминал"
    echo "   SUPER + B - браузер"
    echo ""
    echo "🔍 Полный список клавиш: SUPER + SHIFT + K"
else
    echo -e "${RED}❌ Ошибка при установке!${NC}"
    echo "Попробуйте запустить вручную:"
    echo "sudo nixos-rebuild switch --flake /etc/nixos#$HOSTNAME --show-trace"
    exit 1
fi
