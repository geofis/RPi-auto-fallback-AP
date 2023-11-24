#!/bin/bash

# Nombre del punto de acceso (AP)
AP_NAME="GNSS"

# Comando para activar el punto de acceso
ACTIVATE_CMD="nmcli con up \"$AP_NAME\""

# Verificar si el punto de acceso está activo
ACTIVE_CONNECTION=$(nmcli con show --active | grep "$AP_NAME")

# Si el punto de acceso está inactivo, activarlo.
# Explicación: "- z" devuelve verdadero si la cadena tiene longitud cero.
# Por lo tanto, si grep no encontró la conexión (inactiva),
# $ACTIVE_CONNECTION tendrá longitud cero, y "-z" devolverá  verdadero
if [[ -z $ACTIVE_CONNECTION ]]; then
    # Programar la activación del punto de acceso y cerrar la sesión SSH
    echo "Punto de acceso $AP_NAME inactivo, iniciando activación"
    nohup bash -c "sleep 10; $ACTIVATE_CMD; echo 'Punto de acceso $AP_NAME activado con éxito'" &
    echo "El punto de acceso se activará en 10 segundos..."
    echo "Si puedes, cierra la conexión SSH con 'exit' o 'logout',"
    echo "conéctate a la Raspberry desde el punto de acceso $AP_NAME"
    echo "y accede nuevamente a ella por SSH"
    echo "La clave de punto de acceso es 12345678"
    # Salir del script
    exit
fi
