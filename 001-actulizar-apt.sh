#!/bin/bash


echo "=== Creando nuevo sources.list con repos oficiales de Debian 12 ==="
sudo bash -c 'cat << "EOF" > /etc/apt/sources.list
# Repositorio principal
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware

# Actualizaciones de seguridad
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

# Actualizaciones estables
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
EOF'

echo "=== Actualizando listas de paquetes ==="
sudo apt update

echo "=== Instalando curl ==="
sudo apt install -y curl
 
