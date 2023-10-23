#!/bin/bash

# Nombre del punto de acceso (fallback AP)
AP_NAME="GNSS"

# Verificar si el punto de acceso está activo
ACTIVE_CONNECTION=$(nmcli con show --active | grep "$AP_NAME")

# Si el punto de acceso está activo, desactivarlo
if [[ ! -z $ACTIVE_CONNECTION ]]; then
    echo "Desactivando el punto de acceso $AP_NAME..."
    nmcli con down "$AP_NAME"
    echo "Punto de acceso desactivado con éxito"
fi
