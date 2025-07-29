#!/bin/bash

: <<'comentario-BASH'
sudo apt remove --purge php php-* -y
sudo apt autoremove -y

laravel --version
composer --version
php -v

cat /etc/os-release

comentario-BASH

 # --- Configuración de manejo de errores ---
set -euo pipefail

# --- Variables ---
PHP_VERSION="8.2" # Versión de PHP recomendada para Laravel 10/11.

# --- Funciones de Logging ---
log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1" >&2; }

# --- Funciones Principales ---

install_php_composer_laravel_installer() {
    log "Descargando e instalando PHP ($PHP_VERSION), Composer y Laravel Installer..."

    # --- Instalación de PHP 8.2 en Debian ---
    # Usaremos los repositorios estándar de Debian 12 (Bookworm) para PHP 8.2.
    log "Actualizando lista de paquetes y asegurando dependencias básicas..."
    sudo apt update
    sudo apt install -y curl gnupg apt-transport-https ca-certificates lsb-release software-properties-common


    log "Instalando PHP $PHP_VERSION y extensiones desde repositorios estándar de Debian..."
    # NOTA: Se eliminó la coma después de php$PHP_VERSION-xmlrpc
    # Construimos la lista de paquetes en una variable para mayor claridad
    php_packages=(
        "php$PHP_VERSION"
        "php$PHP_VERSION-cli"
        "php$PHP_VERSION-common"
        "php$PHP_VERSION-mysql"
        "php$PHP_VERSION-mbstring"
        "php$PHP_VERSION-xml"
        "php$PHP_VERSION-curl"
        "php$PHP_VERSION-zip"
        "php$PHP_VERSION-bcmath"
        "php$PHP_VERSION-intl"
        "php$PHP_VERSION-gd"
        "php$PHP_VERSION-opcache"
        "php$PHP_VERSION-readline"
        "php$PHP_VERSION-xmlrpc"
        # Opcional: para Apache, descomentar la línea de abajo si vas a usar Apache
        # "libapache2-mod-php$PHP_VERSION"
    )

    if ! sudo apt install -y "${php_packages[@]}"; then
        error "Falló la instalación de PHP $PHP_VERSION y sus extensiones desde los repositorios de Debian."
        error "Verifica que tu sistema Debian esté actualizado y tenga acceso a los repositorios principales."
        exit 1
    fi

    success "PHP $PHP_VERSION instalado. Versión: $(php -v | head -n 1)"

    # --- Recargar configuraciones de shell ---
    # Asegura que los nuevos comandos de PHP estén en el PATH.
    if [ -f "$HOME/.profile" ]; then source "$HOME/.profile"; fi
    if [ -f "$HOME/.bashrc" ]; then source "$HOME/.bashrc"; fi
    if [ -f "$HOME/.zshrc" ]; then source "$HOME/.zshrc"; fi

    if ! command -v php &> /dev/null; then
        error "Comando 'php' no encontrado después de la instalación. Reinicia la terminal o verifica el PATH."
        exit 1
    fi

    # --- Instalación de Composer ---
    log "Instalando Composer..."
    local composer_installer="composer-setup.php"
    if ! curl -sS https://getcomposer.org/installer -o $composer_installer; then
        error "No se pudo descargar el instalador de Composer."
        exit 1
    fi

    # --- VERIFICA Y ACTUALIZA ESTE HASH ---
    # Ve a https://getcomposer.org/download/ y obtén el hash SHA-384 actual del instalador.
    # Reemplaza el hash que está aquí por el nuevo si este script falla.
    local composer_expected_hash="dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6" # <-- ACTUALIZA ESTE HASH SI ES NECESARIO

    if [ "$(php -r "echo hash_file('sha384', '$composer_installer');")" != "$composer_expected_hash" ]; then
        error "El instalador de Composer está corrupto o el hash ha cambiado."
        error "Por favor, actualiza el hash en el script P01-setup-dev-env.sh con el valor de https://getcomposer.org/download/"
        rm -f $composer_installer
        exit 1
    fi
    # --- FIN VERIFICACIÓN DE HASH ---

    if ! sudo php $composer_installer -- --install-dir=/usr/local/bin --filename=composer; then
        error "Falló la instalación global de Composer. Verifica permisos o conexión."
        rm -f $composer_installer
        exit 1
    fi
    rm -f $composer_installer
    success "Composer instalado correctamente."
    log "Composer version: $(composer --version)"

    # --- Instalación del instalador global de Laravel ---
    log "Instalando el instalador global de Laravel..."
    composer global require laravel/installer

    # --- Configurar el PATH para Composer Bin ---
    local composer_bin_path="$HOME/.config/composer/vendor/bin"
    if [[ ":$PATH:" != *":$composer_bin_path:"* ]]; then
        log "Añadiendo $composer_bin_path a tu PATH en ~/.bashrc..."
        echo "export PATH=\"\$PATH:$composer_bin_path\"" >> ~/.bashrc

    fi
    success "Instalador global de Laravel instalado."
    log "Laravel Installer version: $(laravel --version)"
} # <--- LLAVE DE CIERRE CORRECTA DE LA FUNCIÓN

# --- Ejecución Principal ---
log "--- Iniciando configuración del entorno de desarrollo PHP/Laravel ---"
install_php_composer_laravel_installer

echo ""
log "¡Configuración inicial completada!"
log "Ahora puedes crear tu proyecto Laravel con:"
log "laravel new MiProyectoLaravel"
log ""
log "Después de crear tu proyecto (ej: cd MiProyectoLaravel),"
log "ejecuta el script P04-insta-mariadb-prod.sh para instalar MariaDB y configurar tu proyecto:"
log "bash ../P04-insta-mariadb-prod.sh" # Asume que el segundo script está en el directorio padre
exit 0
