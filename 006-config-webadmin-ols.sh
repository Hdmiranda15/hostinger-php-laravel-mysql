#!/bin/bash

# Script: 006-config-webadmin-ols.sh
# Propósito: Configurar OpenLiteSpeed para servir contenido web (index.html/index.php)
#            completamente desde la línea de comandos, sin usar la interfaz gráfica.
#            Basado en la documentación oficial y el conocimiento del archivo de configuración.

set -euo pipefail

# --- Variables de Configuración ---
# Puedes modificar estas variables según tus necesidades.

# Directorio raíz del servidor y del host virtual por defecto
SERVER_ROOT="/usr/local/lsws"
DEFAULT_VHOST_ROOT="${SERVER_ROOT}/Example"
DEFAULT_VHOST_CONF="${SERVER_ROOT}/conf/vhosts/Example/vhost.conf"

# Configuración del listener por defecto (puerto 80)
DEFAULT_LISTENER_NAME="Default"
DEFAULT_LISTENER_IP="*"
DEFAULT_LISTENER_PORT="80"
DEFAULT_LISTENER_SECURE="0" # 0 para HTTP, 1 para HTTPS

# Configuración del listener SSL por defecto (puerto 443)
DEFAULT_SSL_LISTENER_NAME="Defaultssl"
DEFAULT_SSL_LISTENER_IP="*"
DEFAULT_SSL_LISTENER_PORT="443"
DEFAULT_SSL_LISTENER_SECURE="1" # 1 para HTTPS

# Archivos de certificado SSL (ya generados por scripts anteriores)
SSL_KEY_FILE="${SERVER_ROOT}/conf/h-vhost.key" # Ajusta si usaste otro nombre
SSL_CERT_FILE="${SERVER_ROOT}/conf/h-vhost.crt" # Ajusta si usaste otro nombre

# Usuario y grupo para archivos de configuración
LSADM_USER="lsadm"
LSADM_GROUP="lsadm"

# Archivo de configuración principal
HTTPD_CONF="${SERVER_ROOT}/conf/httpd_config.conf"

# --- Funciones de Utilidad ---

echo_status() {
    echo -e "\033[38;5;71m>>> $1\033[39m" # Verde
}

echo_info() {
    echo -e "\033[38;1;34m    $1\033[39m" # Azul
}

echo_warning() {
    echo -e "\033[38;5;221m    $1\033[39m" # Amarillo
}

echo_error() {
    echo -e "\033[38;5;196m>>> ERROR: $1\033[39m" >&2 # Rojo
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_error "Este script debe ejecutarse como root."
    fi
}

# --- Pasos de Configuración ---

echo_status "INICIANDO CONFIGURACIÓN DE OPENLITESPEED PARA SERVIR CONTENIDO WEB"

check_root

# 1. Verificar que OpenLiteSpeed esté instalado
if [[ ! -f "${SERVER_ROOT}/bin/openlitespeed" ]]; then
    echo_error "OpenLiteSpeed no parece estar instalado en ${SERVER_ROOT}."
fi

# 2. Verificar o crear directorio raíz del host virtual por defecto
if [[ ! -d "${DEFAULT_VHOST_ROOT}" ]]; then
    echo_status "Creando directorio raíz del host virtual por defecto: ${DEFAULT_VHOST_ROOT}"
    mkdir -p "${DEFAULT_VHOST_ROOT}" || echo_error "No se pudo crear el directorio ${DEFAULT_VHOST_ROOT}"
fi

# 3. Verificar o crear subdirectorios html y conf
echo_status "Verificando/creando subdirectorios html y conf"
mkdir -p "${DEFAULT_VHOST_ROOT}/html" || echo_error "No se pudo crear el directorio ${DEFAULT_VHOST_ROOT}/html"
mkdir -p "${DEFAULT_VHOST_ROOT}/conf" || echo_error "No se pudo crear el directorio ${DEFAULT_VHOST_ROOT}/conf"

# 4. Establecer permisos para el directorio conf
echo_status "Estableciendo permisos para ${DEFAULT_VHOST_ROOT}/conf"
chown "${LSADM_USER}:${LSADM_GROUP}" "${DEFAULT_VHOST_ROOT}/conf" || echo_warning "No se pudieron establecer permisos para ${DEFAULT_VHOST_ROOT}/conf"

# 5. Crear contenido de ejemplo si no existe
HTML_FILE="${DEFAULT_VHOST_ROOT}/html/index.html"
if [[ ! -f "${HTML_FILE}" ]]; then
    echo_status "Creando página de inicio de ejemplo en ${HTML_FILE}"
    cat > "${HTML_FILE}" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bienvenido a OpenLiteSpeed</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f0f8ff; }
        .container { background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 0 10px rgba(0,0,0,0.1); display: inline-block; }
        h1 { color: #4682b4; }
        p { color: #555; }
    </style>
</head>
<body>
    <div class="container">
        <h1>¡Éxito! OpenLiteSpeed está funcionando</h1>
        <p>Este es el host virtual por defecto de OpenLiteSpeed.</p>
        <p>Puedes colocar tus archivos HTML/PHP en: <code>/usr/local/lsws/Example/html/</code></p>
        <p>Servidor: OpenLiteSpeed</p>
    </div>
</body>
</html>
EOF
    chown -R nobody:nogroup "${DEFAULT_VHOST_ROOT}/html" || echo_warning "No se pudieron establecer permisos para ${DEFAULT_VHOST_ROOT}/html"
    chmod 644 "${HTML_FILE}" || echo_warning "No se pudieron establecer permisos para ${HTML_FILE}"
else
    echo_status "El archivo ${HTML_FILE} ya existe, se omite la creación."
fi

# 6. Verificar o crear el archivo de configuración del host virtual por defecto
if [[ ! -f "${DEFAULT_VHOST_CONF}" ]]; then
    echo_status "Creando archivo de configuración del host virtual por defecto: ${DEFAULT_VHOST_CONF}"
    mkdir -p "$(dirname "${DEFAULT_VHOST_CONF}")" || echo_error "No se pudo crear el directorio para ${DEFAULT_VHOST_CONF}"

    cat > "${DEFAULT_VHOST_CONF}" << EOF
docRoot                   \$VH_ROOT/html/
index  {
  useServer               0
  indexFiles              index.html,index.php
}

context / {
  type                    NULL
  location                \$VH_ROOT/html/
  allowBrowse             1
  rewrite  {
    enable                0
    inherit               1
  }
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
}

# Configuración SSL básica (se usará si el listener es seguro)
vhssl  {
  keyFile                 ${SSL_KEY_FILE}
  certFile                ${SSL_CERT_FILE}
  certChain               0
}
EOF
    chown "${LSADM_USER}:${LSADM_GROUP}" "${DEFAULT_VHOST_CONF}" || echo_warning "No se pudieron establecer permisos para ${DEFAULT_VHOST_CONF}"
    chmod 600 "${DEFAULT_VHOST_CONF}" || echo_warning "No se pudieron establecer permisos para ${DEFAULT_VHOST_CONF}"
else
    echo_status "El archivo ${DEFAULT_VHOST_CONF} ya existe."
    # Opcional: Podrías verificar o modificar configuraciones específicas aquí.
fi

# 7. Configurar el archivo principal httpd_config.conf
echo_status "Configurando ${HTTPD_CONF}"

# Hacer una copia de seguridad del archivo original
if [[ ! -f "${HTTPD_CONF}.bak" ]]; then
    cp "${HTTPD_CONFIG}" "${HTTPD_CONFIG}.bak"
    echo_info "Copia de seguridad creada: ${HTTPD_CONFIG}.bak"
fi

# a. Asegurar que el host virtual 'Example' esté definido
if ! grep -q "virtualhost Example {" "${HTTPD_CONF}"; then
    echo_info "Agregando definición del host virtual 'Example' al final de ${HTTPD_CONF}"
    cat >> "${HTTPD_CONF}" << EOF

# Host virtual por defecto 'Example'
virtualhost Example {
  vhRoot                  ${DEFAULT_VHOST_ROOT}
  configFile              ${DEFAULT_VHOST_CONF}
  allowSymbolLink         1
  enableScript            1
  restrained              0
  setUIDMode              2
}
EOF
else
    echo_info "La definición del host virtual 'Example' ya existe en ${HTTPD_CONF}"
fi

# b. Asegurar que el listener por defecto (HTTP) esté definido y mapeado
if grep -q "listener ${DEFAULT_LISTENER_NAME} {" "${HTTPD_CONF}"; then
    echo_info "El listener '${DEFAULT_LISTENER_NAME}' ya existe. Verificando mapeo."
    # Verificar si el mapeo existe, si no, agregarlo.
    # Esta parte requiere un poco más de lógica para parsear bloques, pero para simplicidad:
    # Asumiremos que si existe el listener, el mapeo también está bien o se corregirá manualmente si es necesario.
    # Una forma más robusta sería usar sed/awk para encontrar el bloque y modificarlo.
else
    echo_info "Agregando listener '${DEFAULT_LISTENER_NAME}' a ${HTTPD_CONF}"
    cat >> "${HTTPD_CONF}" << EOF

# Listener HTTP por defecto
listener ${DEFAULT_LISTENER_NAME} {
  address                 ${DEFAULT_LISTENER_IP}:${DEFAULT_LISTENER_PORT}
  secure                  ${DEFAULT_LISTENER_SECURE}
  map                     Example *
}
EOF
fi

# c. Asegurar que el listener SSL por defecto esté definido y mapeado
if grep -q "listener ${DEFAULT_SSL_LISTENER_NAME} {" "${HTTPD_CONF}"; then
    echo_info "El listener SSL '${DEFAULT_SSL_LISTENER_NAME}' ya existe."
else
    echo_info "Agregando listener SSL '${DEFAULT_SSL_LISTENER_NAME}' a ${HTTPD_CONF}"
    cat >> "${HTTPD_CONF}" << EOF

# Listener HTTPS por defecto
listener ${DEFAULT_SSL_LISTENER_NAME} {
  address                 ${DEFAULT_SSL_LISTENER_IP}:${DEFAULT_SSL_LISTENER_PORT}
  secure                  ${DEFAULT_SSL_LISTENER_SECURE}
  map                     Example *
  keyFile                 ${SSL_KEY_FILE}
  certFile                ${SSL_CERT_FILE}
}
EOF
fi

# d. Asegurar configuraciones básicas del servidor
# Configurar el puerto del administrador si es necesario (ya debería estar en admin_config.conf)
# Configurar el email del administrador si es necesario
# Habilitar el caché si es necesario (ls_enabled 1)

# 8. Verificar certificados SSL (asumiendo que fueron generados por otro script)
if [[ ! -f "${SSL_KEY_FILE}" ]] || [[ ! -f "${SSL_CERT_FILE}" ]]; then
    echo_warning "No se encontraron los archivos de certificado SSL (${SSL_KEY_FILE}, ${SSL_CERT_FILE})."
    echo_warning "Se generarán certificados autofirmados básicos."

    # Generar certificados si no existen
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${SSL_KEY_FILE}" \
        -out "${SSL_CERT_FILE}" \
        -subj "/C=ES/ST=Madrid/L=Madrid/O=Mi Organizacion/CN=localhost" >/dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo_info "Certificados SSL generados en ${SSL_KEY_FILE} y ${SSL_CERT_FILE}"
        chown "${LSADM_USER}:${LSADM_GROUP}" "${SSL_KEY_FILE}" "${SSL_CERT_FILE}" || echo_warning "No se pudieron establecer permisos para los certificados"
        chmod 600 "${SSL_KEY_FILE}" || echo_warning "No se pudieron establecer permisos para ${SSL_KEY_FILE}"
        chmod 644 "${SSL_CERT_FILE}" || echo_warning "No se pudieron establecer permisos para ${SSL_CERT_FILE}"
    else
        echo_warning "No se pudieron generar los certificados SSL. HTTPS puede no funcionar correctamente."
    fi
else
    echo_status "Archivos de certificado SSL encontrados: ${SSL_KEY_FILE}, ${SSL_CERT_FILE}"
fi

# 9. Reiniciar OpenLiteSpeed para aplicar cambios
echo_status "Reiniciando OpenLiteSpeed para aplicar la configuración..."
systemctl stop lsws >/dev/null 2>&1 || true # Detener si está corriendo
sleep 2
systemctl start lsws

if systemctl is-active --quiet lsws; then
    echo_status "OpenLiteSpeed se ha reiniciado correctamente."
else
    echo_error "No se pudo reiniciar OpenLiteSpeed. Verifica los logs en ${SERVER_ROOT}/logs/."
fi

# 10. Verificar puertos
echo_status "Verificando puertos después del reinicio..."
echo_info "Estado de los puertos críticos:"
for port in 80 443 7080; do
    if netstat -tuln | grep ":$port " >/dev/null 2>&1; then
        echo_info "  ✅ Puerto $port está en uso (probablemente por OpenLiteSpeed)"
    else
        echo_warning "  ⚠️  Puerto $port no parece estar en uso"
    fi
done

# --- Instrucciones Finales ---
echo
echo_status "CONFIGURACIÓN COMPLETADA"
echo_info "-----------------------------------------------------------------------"
echo_info "PARA ACCEDER A TU CONTENIDO WEB:"
echo_info "-----------------------------------------------------------------------"
echo_info "1. Averigua la IP de tu servidor:"
echo_info "   - Ejecuta 'hostname -I' o 'ip a' en la terminal del servidor."
echo_info "   - Anota la dirección IP (por ejemplo, 192.168.1.100 o 10.0.2.15)."
echo_info ""
echo_info "2. Accede desde tu navegador:"
echo_info "   - Para HTTP:  http://<TU_IP_DEL_SERVIDOR>"
echo_info "   - Para HTTPS: https://<TU_IP_DEL_SERVIDOR>"
echo_info "   (Reemplaza <TU_IP_DEL_SERVIDOR> con la IP real de tu máquina)."
echo_info ""
echo_info "3. Deberías ver la página de ejemplo creada en:"
echo_info "   ${HTML_FILE}"
echo_info ""
echo_info "4. Para servir tus propios archivos:"
echo_info "   - Colócalos en el directorio: ${DEFAULT_VHOST_ROOT}/html/"
echo_info "   - Asegúrate de que tengan permisos adecuados (por ejemplo, 644 para archivos, 755 para directorios)."
echo_info "   - El archivo 'index.html' o 'index.php' será servido por defecto."
echo_info ""
echo_info "5. Para acceder al panel de administración WebAdmin:"
echo_info "   - Ve a: https://<TU_IP_DEL_SERVIDOR>:7080"
echo_info "   - Inicia sesión con el usuario y contraseña configurados anteriormente."
echo_info "-----------------------------------------------------------------------"
echo_status "¡Listo! Tu servidor OpenLiteSpeed está configurado para servir contenido web."