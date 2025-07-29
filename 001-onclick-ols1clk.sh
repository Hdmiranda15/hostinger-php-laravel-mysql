#!/bin/bash

# Descarga primero el script
echo "Descargando el script de instalaci�n..."
curl -k -o ols1clk.sh https://raw.githubusercontent.com/litespeedtech/ols1clk/master/ols1clk.sh

# Verifica si la descarga fue exitosa
if [ $? -ne 0 ]; then
    echo "Error al descargar el script ols1clk.sh"
    exit 1
fi

# Hacer el script descargado ejecutable
chmod +x ols1clk.sh

# Ejecutar el script descargado con tus opciones
echo "Ejecutando el script de instalaci�n..."
./ols1clk.sh --pure-mariadb --adminuser h-olp -A 12345 --lsphp 82 "$@"

# Opcional: Eliminar el script descargado despu�s de la ejecuci�n
# rm ols1clk.sh
