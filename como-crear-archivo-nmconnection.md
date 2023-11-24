# Cómo crear un archivo de conexión (.nmconnection) de NetworkManager

Si lo que se necesita es conectar la Raspberry a una red de infraestructura WiFi, sigue estos pasos:

1. **Monta la tarjeta microSD en tu computadora**. Deberías ver dos particiones: `boot` y `rootfs` (o simplemente la partición del sistema).

2. **Crea o modifica la configuración de red para NetworkManager**:

   Ve a la partición donde está el sistema operativo, normalmente denominada `rootfs`. Dentro de esa partición, navega a `/etc/NetworkManager/system-connections/`.

   Aquí, puedes agregar un archivo de configuración para tu red Wi-Fi. El archivo podría llamarse `miRedWiFi.nmconnection` (o cualquier otro nombre distintivo con la extensión `.nmconnection`). El contenido del archivo debe ser algo como esto:

   ```plaintext
   [connection]
   id=miRedWiFi
   uuid=one-two-three-etc # Puedes usar uuidgen para generar uno
   type=wifi

   [wifi]
   mode=infrastructure
   ssid=miRedWiFi

   [wifi-security]
   key-mgmt=wpa-psk
   psk=miClave
   ```

   Asegúrate de reemplazar `miRedWiFi` con el nombre de tu red Wi-Fi y `miClave` con la contraseña correspondiente.

3. **IMPORTANTE**: cambia los permisos del archivo:

   Ejecuta `chmod 600 miRedWiFi.nmconnection`

4. Si no lo está, **habilita SSH**:
   
   Si ya tenías acceso SSH pero por alguna razón ya no puedes acceder, asegúrate de que el servicio SSH esté habilitado. Para ello, navega a la partición `boot` y verifica si hay un archivo llamado `ssh` (sin extensión). Si no está presente, crea uno. 

   Esto le indicará a Raspberry Pi OS que habilite el servidor SSH en el arranque.

5. **Desmonta y coloca la microSD en la Raspberry Pi**. Luego enciende la Raspberry.

6. **Accede a la Raspberry Pi vía SSH**. Una vez que la Raspberry Pi haya arrancado y se haya conectado a la red Wi-Fi, puedes acceder a ella vía SSH. Si no conoces la dirección IP de tu Raspberry, puedes buscarla en la interfaz de tu router o usar herramientas como `nmap` o `arp-scan` para escanear tu red local.

   ```bash
   ssh pi@raspberry_ip_address
   ```

   Por defecto, el nombre de usuario es `pi` y la contraseña es `raspberry`, a menos que hayas cambiado estos valores previamente.

