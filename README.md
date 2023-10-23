# RPi-auto-fallback-AP

- Crea una conexión secundaria, o conexión alternativa como punto de acceso (*access point*, AP) en la RPi. Si no encuentra red WiFi para conectarse, se conecta al AP.

- Instala scripts para:

  - Crear credenciales de red WiFi.
  - Apagar el AP.

- Instala un watchdog para vigilar la conexión WiFi. Si está ausente, pasa a la secundaria.

TODO:

- Centralizar variables (SSID y PASS del AP) usando archivo config.txt (requiere script de creación de archivo config.txt).

- Centralizar funciones en archivo `functions.sh`.

- Crear logrotate para el log del watchdog.
