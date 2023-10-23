#!/bin/bash

# Copiar script para habilitar el punto de acceso
echo "Configurando el modo punto de acceso...\n"
cp dispatchers/99-fallback /etc/NetworkManager/dispatcher.d/
chmod +x /etc/NetworkManager/dispatcher.d/99-fallback
echo "Creado exitosamente el punto de acceso.\n"

# Copiar herramientas
cp tools/create-network-credentials.sh /usr/local/bin/
chmod +x /usr/local/bin/create-network-credentials.sh
cp tools/turn-off-ap.sh /usr/local/bin/
chmod +x /usr/local/bin/turn-off-ap.sh

# Copiar script y servicio vigia
cp watchdogs/wifi-watchdog.sh /usr/local/bin/
chmod +x /usr/local/bin/wifi-watchdog.sh
cp services/wifi-watchdog.service /etc/systemd/system/

# Habilitar servicio e iniciarlo
systemctl enable wifi-watchdog.service
systemctl start wifi-watchdog.service

echo "Reinicia la Raspberry con 'sudo reboot'\n"
echo "Tras reiniciar, conéctate a ella a través de la red 'GNSS'\n"

# Presiona ENTER para reiniciar
read -p "Presiona ENTER para salir" x
