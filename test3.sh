#!/bin/bash

# Скрипт для установки зависимостей и деплоя простой HTML игры
# Автор: Claude
# Дата: 19 марта 2025

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Функция для вывода статуса
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка наличия необходимых утилит
check_dependencies() {
    print_status "Проверка зависимостей..."
    
    # Проверка наличия nginx
    if ! command -v nginx &> /dev/null; then
        print_status "Nginx не найден. Устанавливаем..."
        apt-get update
        apt-get install -y nginx
        if [ $? -ne 0 ]; then
            print_error "Не удалось установить nginx. Выход."
            exit 1
        fi
        print_success "Nginx успешно установлен"
    else
        print_success "Nginx уже установлен"
    fi
    
    # Проверка наличия git
    if ! command -v git &> /dev/null; then
        print_status "Git не найден. Устанавливаем..."
        apt-get update
        apt-get install -y git
        if [ $? -ne 0 ]; then
            print_error "Не удалось установить git. Выход."
            exit 1
        fi
        print_success "Git успешно установлен"
    else
        print_success "Git уже установлен"
    fi
}

# Клонирование репозитория
clone_repository() {
    print_status "Клонирование репозитория..."
    
    # Проверяем, передан ли URL репозитория
    if [ -z "$1" ]; then
        print_error "URL репозитория не указан. Использование: $0 <git_url> [branch]"
        exit 1
    fi
    
    GIT_URL=$1
    BRANCH=${2:-main}  # По умолчанию используем ветку main
    
    # Создаем директорию для приложения, если она не существует
    APP_DIR="/var/www/airplane-game"
    mkdir -p $APP_DIR
    
    # Клонируем репозиторий
    git clone $GIT_URL -b $BRANCH $APP_DIR/repo
    
    if [ $? -ne 0 ]; then
        print_error "Не удалось клонировать репозиторий. Выход."
        exit 1
    fi
    
    print_success "Репозиторий успешно клонирован"
    
    # Копируем файлы из репозитория
    cp -r $APP_DIR/repo/* $APP_DIR/
    
    # Удаляем директорию .git
    rm -rf $APP_DIR/repo
}

# Настройка Nginx
configure_nginx() {
    print_status "Настройка Nginx..."
    
    # Создаем конфигурацию для Nginx
    cat > /etc/nginx/sites-available/airplane-game << EOF
server {
    listen 80;
    server_name _;
    
    root /var/www/airplane-game;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Включаем конфигурацию
    ln -sf /etc/nginx/sites-available/airplane-game /etc/nginx/sites-enabled/
    
    # Удаляем конфигурацию по умолчанию
    rm -f /etc/nginx/sites-enabled/default
    
    # Проверяем конфигурацию Nginx
    nginx -t
    
    if [ $? -ne 0 ]; then
        print_error "Некорректная конфигурация Nginx. Выход."
        exit 1
    fi
    
    # Перезапускаем Nginx
    systemctl restart nginx
    
    if [ $? -ne 0 ]; then
        print_error "Не удалось перезапустить Nginx. Выход."
        exit 1
    fi
    
    print_success "Nginx успешно настроен"
}

# Применение прав доступа
set_permissions() {
    print_status "Настройка прав доступа..."
    
    # Устанавливаем владельца и права доступа
    chown -R www-data:www-data /var/www/airplane-game
    chmod -R 755 /var/www/airplane-game
    
    print_success "Права доступа успешно настроены"
}

# Отображение информации о деплое
display_info() {
    # Получаем IP-адрес сервера
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    
    print_success "Деплой успешно завершен!"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}Игра доступна по адресу: http://$IP_ADDRESS${NC}"
    echo -e "${GREEN}=======================================${NC}"
}

# Основная функция
main() {
    print_status "Начинаем процесс установки и деплоя..."
    
    # Проверяем, запущен ли скрипт от имени root
    if [ "$EUID" -ne 0 ]; then
        print_error "Пожалуйста, запустите скрипт от имени root (sudo $0)"
        exit 1
    fi
    
    # Выполняем все шаги
    check_dependencies
    clone_repository "$@"
    configure_nginx
    set_permissions
    display_info
}

# Запускаем скрипт
main "$@"
