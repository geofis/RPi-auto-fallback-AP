#!/bin/bash

# Pedir al usuario que ingrese el SSID de la red
read -p "Introduce el SSID de la red a la que deseas conectarte: " target_ssid

# Pedir la contraseña de la red
#read -sp "Introduce la contraseña de la red (si tiene): " target_pass


# Pedir la contraseña de la red
attempts=0
while true; do
    # Pedir la contraseña de la red
    read -sp "Introduce la contraseña de la red (si tiene): " target_pass
    echo ""  # simplemente para agregar una nueva línea después de que el usuario introduce la contraseña

    # Confirmar contraseña
    read -sp "Confirma la contraseña: " confirm_pass
    echo ""  # simplemente para agregar una nueva línea

    if [[ "$target_pass" == "$confirm_pass" ]]; then
        echo "Las contraseñas coinciden."
        break  # Salir del bucle
    else
        echo "Las contraseñas no coinciden."
        ((attempts++))
        if [ $attempts -ge 3 ]; then
            echo "Demasiados intentos fallidos. Saliendo del script."
            exit 1
        fi
    fi
done

# Eliminar todas las conexiones Wi-Fi conocidas excepto el fallback
for uuid in $(nmcli -t -f NAME,UUID con show | grep -vE "GNSS|lo" | cut -d':' -f2)
do
    nmcli con delete uuid "$uuid"
done

# Agregar la nueva conexión
nmcli con add con-name "$target_ssid" type wifi ifname wlan0 ssid "$target_ssid"
nmcli con modify "$target_ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$target_pass"

echo "Configuración completada."
echo "Ahora, desactiva el punto de acceso con sudo bash turn-off-ap.sh"
exit

# Intentar conexión.
#echo "Intentando conectar..."
##echo "Reiniciando NetworkManager"
##systemctl restart NetworkManager
#if ! nmcli dev wifi con "$target_ssid" password "$target_pass"; then
#    echo "El intento de conexión falló, pero la conexión se añadió con éxito."
#fi
