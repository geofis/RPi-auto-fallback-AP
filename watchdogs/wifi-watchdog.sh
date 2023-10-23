#!/bin/bash

fallback_ssid="GNSS"

log_file="/var/log/wifi-watchdog.log"

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

log_command_output() {
    while read -r line; do
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $line" >> "$log_file"
    done
}

check_wifi() {
    local output
    output=$(nmcli -t -f DEVICE,STATE device | grep wlan0 | grep ":connected" 2>&1)
    local retval=$?  # Guarda el valor de salida de grep
    echo "$output" | log_command_output
    return $retval
}

connect_to_known_network() {
    local IFS=$'\n'
    for conn in $(nmcli -t -f NAME,UUID con show | grep -vE "GNSS|lo" | cut -d':' -f1)
    do
        log_message "Intentando conectarse a la red: $conn"
        nmcli con up id "$conn" 2>&1 | log_command_output
        sleep 10
        if check_wifi; then
            log_message "Conexión exitosa a la red: $conn"
            return 0
        else
            log_message "Fallo al intentar conectarse a la red: $conn"
        fi
    done
    return 1
}

while true; do
    sleep 60  # Verifica cada 60 segundos
    if ! check_wifi; then
        log_message "WiFi desconectado. Intentando reconectar..."
        if ! connect_to_known_network; then
            log_message "Intentando conectarse a la red de respaldo: $fallback_ssid"
            nmcli con up "$fallback_ssid" 2>&1 | log_command_output
        fi
    else
        log_message "WiFi conectado correctamente."
    fi
done

