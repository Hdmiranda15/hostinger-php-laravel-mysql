#!/bin/bash

# Habilita un modo estricto para el script
set -euo pipefail

echo "========================================================="
echo "===     INICIANDO PURGA TOTAL DEL ENTORNO ANTERIOR    ==="
echo "========================================================="

echo ">>> Paso 1: Deteniendo servicios relacionados (si existen)..."
systemctl stop lsws.service 2>/dev/null || true
systemctl stop mariadb.service 2>/dev/null || true
systemctl stop mysql.service 2>/dev/null || true
systemctl stop mysqld.service 2>/dev/null || true
systemctl disable lsws.service 2>/dev/null || true

echo ">>> Paso 2: Matando procesos que puedan estar usando puertos críticos..."
for port in 80 443 7080 3306; do
    echo "Buscando procesos en el puerto $port..."
    pids=$(lsof -t -i :$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "Matando procesos en el puerto $port (PIDs: $pids)"
        kill -9 $pids 2>/dev/null || true
    else
        echo "No se encontraron procesos en el puerto $port"
    fi
done

echo ">>> Paso 3: Corrigiendo posibles permisos de phpdismod..."
# Intentar corregir permisos si los archivos aún existen
find /usr/local/lsws/ -name "phpdismod" -type f -exec chmod +x {} \; 2>/dev/null || true

echo ">>> Paso 4: Forzando eliminación de paquetes problemáticos..."
# Intentar eliminar paquetes específicos con más fuerza
apt-get --purge -y --force-yes remove openlitespeed* lsphp* mariadb* mysql* percona* ols-modsecurity* 2>/dev/null || true
dpkg --remove --force-remove-reinstreq lsphp82* lsphp83* 2>/dev/null || true # Fuerza eliminación de paquetes rotos

echo ">>> Paso 5: Purgando paquetes y limpiando..."
apt-get purge -y openlitespeed* lsphp* mariadb* mysql* percona* || true
apt-get autoremove -y --purge || true # --purge asegura eliminar configs
apt-get clean || true

echo ">>> Paso 6: Eliminando directorios residuales..."
rm -rf /usr/local/lsws
rm -rf /var/www/html/localhost
rm -rf /etc/openlitespeed
rm -f /etc/apt/sources.list.d/litespeed*.list
rm -f /etc/apt/sources.list.d/MariaDB*.list
rm -rf /var/lib/mysql
rm -rf /var/lib/mariadb
rm -rf /var/log/mysql*
rm -rf /var/log/mariadb*
rm -f /etc/mysql/*
rm -f /etc/my.cnf*
rm -rf /etc/my.cnf.d
rm -f /etc/logrotate.d/lsws
rm -f /etc/systemd/system/lsws.service

echo ">>> Paso 7: Eliminando usuario y grupo del sitio (si existen)..."
for user in lsadm nobody h-litespeed; do
    if id "$user" &>/dev/null; then
        echo "Eliminando usuario '$user'..."
        userdel "$user" 2>/dev/null || true
    fi
done

for group in lsadm nobody h-litespeed; do
    if getent group "$group" &>/dev/null; then
        echo "Eliminando grupo '$group'..."
        groupdel "$group" 2>/dev/null || true
    fi
done

echo ">>> Paso 8: Limpiando posibles archivos temporales y cachés..."
rm -rf /tmp/lshttpd
rm -rf /tmp/lsphp*
rm -rf /var/tmp/ls*
# Limpiar posibles configs viejas de dpkg
rm -f /var/lib/dpkg/info/lsphp*-prerm 2>/dev/null || true

echo ">>> Paso 9: Recargando systemd y actualizando base de datos de paquetes..."
systemctl daemon-reload || true
# Volver a cargar la lista de paquetes para reflejar los cambios
apt-get update >/dev/null 2>&1 || true

echo ">>> Paso 10: Verificando puertos después de la limpieza..."
echo "Estado de los puertos críticos:"
for port in 80 443 7080 3306; do
    if netstat -tuln | grep ":$port " >/dev/null 2>&1; then
        echo "  ⚠️  Puerto $port aún está en uso"
        netstat -tulnp | grep ":$port " || true
    else
        echo "  ✅ Puerto $port está libre"
    fi
done

echo "========================================================="
echo "===          PURGA TOTAL COMPLETADA                   ==="
echo "========================================================="
echo "Se han eliminado:"
echo "  - Todos los paquetes de OpenLiteSpeed y LSPHP"
echo "  - Todos los paquetes de MariaDB/MySQL/Percona"
echo "  - Todos los directorios de configuración y datos"
echo "  - Todos los usuarios y grupos relacionados"
echo "  - Todos los procesos en puertos 80, 443, 7080, 3306"
echo ""
echo "El sistema está listo para una instalación limpia."
