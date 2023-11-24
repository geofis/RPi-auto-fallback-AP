#!/bin/bash

# Nombre del punto de acceso (fallback AP)
AP_NAME="GNSS"

# Comando para desactivar el punto de acceso
DEACTIVATE_CMD="nmcli con down \"$AP_NAME\""

# Verificar si el punto de acceso está activo
ACTIVE_CONNECTION=$(nmcli con show --active | grep "$AP_NAME")

# Si el punto de acceso está activo, programar su desactivación
if [[ ! -z $ACTIVE_CONNECTION ]]; then
    # Programar la desactivación del punto de acceso y cerrar la sesión SSH
    nohup bash -c "sleep 10; $DEACTIVATE_CMD; echo 'Punto de acceso $AP_NAME desactivado con éxito'" &
    echo "El punto de acceso $AP_NAME se activará en 10 segundos..."
    echo "Si puedes, cierra la conexión SSH con 'exit' o 'logout',"
    echo "conéctate a la Raspberry desde la red WiFI"
    echo "y accede nuevamente ella por SSH"
    # Salir del script
    exit
fi
