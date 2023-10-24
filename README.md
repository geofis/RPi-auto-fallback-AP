# RPi-auto-fallback-AP

- Crea una conexión secundaria, o conexión alternativa como punto de acceso (*access point*, AP) en la RPi. Si no encuentra red WiFi para conectarse, se conecta al AP.

- Instala scripts para:

  - Crear credenciales de red WiFi.
  - Apagar el AP.

- Instala un watchdog para vigilar la conexión WiFi. Si está ausente, pasa a la secundaria.

## Instalación

`sudo apt update`

`sudo apt install git`

`git clone https://github.com/geofis/RPi-auto-fallback-AP.git`

`cd RPi-auto-fallback-AP`

`sudo bash -x install.sh`

## TODO:

- Centralizar variables (SSID y PASS del AP) usando archivo config.txt (requiere script de creación de archivo config.txt).

- Centralizar funciones en archivo `functions.sh`.

- Crear logrotate para el log del watchdog.

- Añadir función para activar el AP. Útil en situaciones en las que no se puede desconectar la infraestructura WiFi.

- Al crear nueva conexión a red de infraestructura, diferir al próximo reinicio el borrado de la actual (si la hubiere).
