#!/bin/bash

# --- Configuraci�n de manejo de errores ---
set -euo pipefail

# --- Variables de Configuraci�n ---
# Deben coincidir con las que defines en el script P01
PHP_VERSION="8.2" # Usado solo para logging
DB_USER="u480098805_laravel"
DB_PASS="Skatecrazy15"
DB_NAME="u480098805_laravel" # Mismo nombre para user y DB

# --- Funciones de Logging ---
log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
error() { echo "[ERROR] $1" >&2; }

# --- Funciones Principales ---

# Funci�n para instalar y configurar MariaDB
install_and_configure_mariadb() {
    log "Verificando e instalando MariaDB..."

    # Verificar si MariaDB ya est� instalado
    if ! command -v mysql &> /dev/null; then
        log "MariaDB no est� instalado. Instalando..."
        # Instalar MariaDB Server y Cliente
        sudo apt update
        sudo apt install -y mariadb-server mariadb-client

        # Asegurar la instalaci�n (ejecutar el script de seguridad)
        log "Ejecutando mysql_secure_installation. Sigue las instrucciones en pantalla."
        log "Ser� necesario establecer una contrase�a para el usuario 'root' de MariaDB."
        # Nota: La contrase�a de root de MariaDB es diferente a tu contrase�a de usuario de Debian.
        if ! sudo mysql_secure_installation; then
            error "mysql_secure_installation fall�. Revisa los pasos o los permisos."
            exit 1
        fi
        success "MariaDB instalado y configuraci�n de seguridad inicializada."
    else
        log "MariaDB ya est� instalado."
        # Nota: Si MariaDB ya est� instalado, este script no vuelve a ejecutar mysql_secure_installation
        # ni se asegura de que la contrase�a de root sea la que esperas, a menos que la definas de otra manera.
        # Para fines de este script, asumimos que si est� instalado, est� razonablemente configurado.
    fi

    # Asegurarse de que el servicio de MariaDB est� iniciado y habilitado
    log "Asegurando que el servicio de MariaDB est� iniciado y habilitado..."
    if ! sudo systemctl is-active --quiet mariadb; then
        sudo systemctl start mariadb
    fi
    sudo systemctl enable mariadb
    success "Servicio MariaDB activo y habilitado."

    # --- Configurar la Base de Datos y el Usuario ---
    log "Creando la base de datos '${DB_NAME}' y el usuario '${DB_USER}'..."

        # Crear un archivo SQL temporal para la configuraci�n
    local sql_commands=$(cat <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
)
    # Nota: 'EOF' debe estar en una l�nea por s� solo, sin espacios ni caracteres adicionales.
    # El par�ntesis de cierre del $() va en la l�nea siguiente.    


    # Ejecutar los comandos SQL.
    # Necesitar� la contrase�a del root de MariaDB (la que se defini� en mysql_secure_installation).
    # El script intentar� pedirla si la conexi�n sin contrase�a falla.

    # Intenta ejecutar como root de MariaDB. Si falla, pide la contrase�a de root de MariaDB.
    if ! echo "$sql_commands" | sudo mariadb; then
       log "No se pudo crear la DB/usuario sin contrase�a de root de MariaDB. Pidiendo contrase�a de root de MariaDB..."
       read -s -p "Introduce la contrase�a de root de MariaDB: " MARIADB_ROOT_PASSWORD
       echo "" # Nueva l�nea despu�s de la entrada de contrase�a

       if ! echo "$sql_commands" | sudo mariadb -u root -p"$MARIADB_ROOT_PASSWORD"; then
           error "Fall� la creaci�n de la base de datos y el usuario. Verifica la contrase�a de root de MariaDB."
           exit 1
       fi
    fi

    success "Base de datos '${DB_NAME}' y usuario '${DB_USER}' creados exitosamente."
}

# Funci�n para configurar el archivo .env del proyecto Laravel
configure_project_env() {
    log "Configurando el archivo .env del proyecto actual..."

    # Asegurarse de que las variables de DB est�n definidas
    if [ -z "${DB_USER:-}" ] || [ -z "${DB_PASS:-}" ] || [ -z "${DB_NAME:-}" ]; then
        error "Las variables de base de datos (DB_USER, DB_PASS, DB_NAME) no est�n definidas correctamente."
        exit 1
    fi

    # Crear .env si no existe, usando .env.example
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            log "Archivo .env creado a partir de .env.example"
        else
            error "No se encontr� .env.example en el directorio actual. No se puede crear .env."
            exit 1
        fi
    fi

    # Sustituir los valores de la base de datos en el archivo .env
    # Usamos `sed -i` para modificar el archivo en su lugar.
    # Las variables de Bash se expanden porque usamos comillas dobles.
    # Usamos `sudo` por si el script se ejecut� con sudo y los permisos de .env no permiten escritura al usuario actual.
    if command -v sudo &> /dev/null; then
        sudo sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
        sudo sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
        sudo sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
        sudo sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env # Asegurar host local
        sudo sed -i "s|^DB_PORT=.*|DB_PORT=3306|" .env       # Asegurar puerto est�ndar
        # Asegurar que la conexi�n sea mysql
        if grep -q "^DB_CONNECTION=.*" .env; then
            sudo sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" .env
        else
            echo "DB_CONNECTION=mysql" >> .env
        fi
    else
        # Si sudo no est� disponible (ej. si ejecutas el script como un usuario sin sudo).
        # En ese caso, aseg�rate de tener permisos de escritura en .env.
        sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
        sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
        sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env
        sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env # Asegurar host local
        sed -i "s|^DB_PORT=.*|DB_PORT=3306|" .env       # Asegurar puerto est�ndar
        if grep -q "^DB_CONNECTION=.*" .env; then
            sed -i "s|^DB_CONNECTION=.*|DB_CONNECTION=mysql|" .env
        else
            echo "DB_CONNECTION=mysql" >> .env
        fi
    fi

    success "Archivo .env configurado para MariaDB."
    log "Valores de MariaDB en .env:"
    echo "DB_DATABASE=${DB_NAME}"
    echo "DB_USERNAME=${DB_USER}"
    echo "DB_PASSWORD=${DB_PASS}"
    echo "DB_HOST=127.0.0.1"
    echo "DB_PORT=3306"
}

# --- Ejecuci�n Principal ---
log "--- Iniciando configuraci�n de proyecto Laravel y MariaDB ---"

# 1. Instalar y configurar MariaDB si no est� ya
install_and_configure_mariadb

# 2. Configurar el archivo .env del proyecto actual
configure_project_env

log ""
success "�Configuraci�n del proyecto Laravel y MariaDB completada!"
log "Ahora puedes:"
log "1. Ejecutar migraciones: php artisan migrate"
log "2. Iniciar el servidor de desarrollo: php artisan serve"

exit 0
