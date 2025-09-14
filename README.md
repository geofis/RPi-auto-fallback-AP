# RPi-auto-fallback-AP (con NetworkManager)

**Objetivo:** cuando la Raspberry **no** consigue conectarse a una Wi-Fi conocida, **levanta un Punto de Acceso (AP)** propio para que puedas entrar y arreglar la conectividad.
Cuando vuelve a detectar alguna red conocida, **corta el AP** y se conecta como cliente.

Este enfoque usa **NetworkManager (nmcli)**, `systemd` y un **timer** + **hook dispatcher**.
Todo queda **loggeado en `journalctl`** con la etiqueta `fallback-ap`.

---

## Características

* Preferencia por **redes conocidas** (con `autoconnect yes`).
* **AP “de emergencia”** con SSID/PSK configurables (IPv4 *shared* → NAT/DHCP por NetworkManager; IP típica 10.42.0.1).
* **Comprobación periódica** (timer cada 90 s) + reacción a eventos de red (hook de dispatcher).
* **Backoff anti-flapping** (mín. 30 s entre cambios de modo).
* **Logs** en `journald` (`-t fallback-ap`) y **modo debug** activable.
* Opción para desactivar **ahorro de energía Wi-Fi** (powersave).
* Multi-interfaz mediante *units* plantillas: `fallback-ap@<iface>.service` y `fallback-ap@<iface>.timer`.

> Requiere **Raspberry Pi OS Bookworm** (o distro con **NetworkManager**). En sistemas antiguos con `dhcpcd` + `wpa_supplicant` sin NM, este repo no aplica.

---

## Instalación rápida

> **Nota:** Si ya tienes restos de versiones previas (servicio `wifi-watchdog`, scripts viejos, etc.), el instalador los limpia.

1. Copia el instalador y ejecútalo:

```bash
curl -fsSL https://raw.githubusercontent.com/geofis/RPi-auto-fallback-AP/main/install_fallback_ap.sh -o install_fallback_ap.sh
sudo bash install_fallback_ap.sh --iface wlan0 --ssid GNSS --pass 12345678 --band bg --chan 6 --interval 60 --boot-delay 20 --force
```

Luego de instalar:

```bash
sudo systemctl daemon-reload
sudo systemctl disable --now 'fallback-ap@wlan0.timer' 2>/dev/null || true
sudo systemctl stop          'fallback-ap@wlan0.service' 2>/dev/null || true
sudo systemctl enable  --now 'fallback-ap@wlan0.timer'
sudo systemctl start         'fallback-ap@wlan0.service'
```

**Parámetros útiles:**

* `--iface` interfaz Wi-Fi (por defecto `wlan0`)
* `--ssid` SSID del AP (por defecto `GNSS`)
* `--pass` clave WPA2 (8–63 chars; por defecto `12345678`)
* `--band` `bg` (2.4 GHz) o `a` (5 GHz); por defecto `bg`
* `--chan` canal (por defecto `6`)
* `--interval` intervalo de búsqueda de redes, en segundos (90s por defecto)
* `--boot-delay` retardo luego del arranque, en segundos (20s por defecto)
* `--no-powersave-tweak` no toca `wifi.powersave`
* `--force` ejecuta evaluación inicial al terminar
* `--status` muestra estado
* `--uninstall` desinstala todo

El instalador:

* Asegura **NetworkManager** instalado/activo.
* Crea `/etc/default/fallback-ap` (config).
* Instala el script `/usr/local/sbin/fallback-ap.sh`.
* Instala los *units* `fallback-ap@.service` y **`fallback-ap@.timer`** (plantilla).
* Crea el hook `/etc/NetworkManager/dispatcher.d/50-fallback-ap`.
* Habilita **`fallback-ap@wlan0.timer`** (o la interfaz que pases).

**Funciones de ayuda:**

```bash
sudo fa-status                    # estado rapido
sudo fa-force-ap                  # simula perdida y levanta AP ya
sudo fa-force-client "TU_SSID"    # migra a cliente ya
sudo fa-add-wifi SSID [PSK]       # crea perfil nuevo ejemplo sudo fa-add-wifi "Pa viejos" clave
sudo fa-forget SSID               # olvida perfil
sudo fa-list                      # despliega perfiles
```

---

## ¿Cómo funciona?

1. **Timer** (`fallback-ap@wlan0.timer`) dispara el service `fallback-ap@wlan0.service`:

   * Intenta conectar a **conexiones Wi-Fi conocidas y autoconnect** (`nmcli con show`).
   * Si no hay éxito, **levanta el AP** “fallback-ap” (SSID/PSK de `/etc/default/fallback-ap`).
2. **Dispatcher** de NetworkManager dispara el service ante eventos (up/down, cambios DHCP, etc.) para reaccionar rápido.
3. **Backoff**: no alterna de cliente↔AP si el último cambio fue hace < 30 s.

---

## Configuración

Archivo: **`/etc/default/fallback-ap`**

```bash
SSID="GNSS"
PASS="12345678"
BAND="bg"       # 'bg' (2.4 GHz) o 'a' (5 GHz)
CHAN="6"
IFACE="wlan0"
BOOT_DELAY="20"
INTERVAL="90"
# Opcional: elevar verbosidad de logs (0|1)
FALLBACK_AP_DEBUG=0
```

> **Seguridad:** usa una PSK robusta (8–63 chars). En 2.4 GHz (`bg`) tendrás más compatibilidad para “modo rescate”.

---

## Órdenes frecuentes

**Estado:**

```bash
# Estado general
sudo systemctl status fallback-ap@wlan0.service
sudo systemctl status fallback-ap@wlan0.timer

# Conexiones activas
nmcli -g NAME,TYPE,DEVICE,GENERAL.STATE con show --active
```

**Logs:**

```bash
# Últimos 100 mensajes del script
journalctl -t fallback-ap -n 100 --no-pager

# En vivo
journalctl -t fallback-ap -f

# Por unidad (y boots anteriores)
journalctl -u fallback-ap@wlan0.service -n 100 -f
journalctl -b -1 -u fallback-ap@wlan0.service
```

**Arranque/parada manual:**

```bash
sudo systemctl start  fallback-ap@wlan0.service
sudo systemctl stop   fallback-ap@wlan0.service
sudo systemctl enable --now fallback-ap@wlan0.timer
```

**Modo debug (más traza):**

```bash
echo 'FALLBACK_AP_DEBUG=1' | sudo tee -a /etc/default/fallback-ap
sudo systemctl start fallback-ap@wlan0.service
journalctl -t fallback-ap -f
```

**Desinstalar:**

```bash
sudo bash install_fallback_ap.sh --uninstall
```

---

## Cómo “sabe” qué redes son conocidas

Busca conexiones de tipo Wi-Fi en NetworkManager **con autoconnect habilitado** (excepto la propia `fallback-ap`).
Revisa con:

```bash
nmcli con show
nmcli con show <NombreConexion> | grep autoconnect
```

Para activar autoconnect:

```bash
nmcli con mod "<NombreConexion>" connection.autoconnect yes
```

---

## Persistencia de logs

Para que los logs no se pierdan tras reinicio:

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

---

## Solución de problemas

* **El AP no sube:**

  * Asegúrate de que **NetworkManager** controla la interfaz:

    ```bash
    nmcli dev set wlan0 managed yes
    nmcli radio wifi on
    rfkill list  # (no debe estar bloqueado)
    ```
  * Revisa logs: `journalctl -t fallback-ap -n 200`.

* **Siempre se queda en cliente aunque la red falle:**

  * Comprueba que realmente **no** está conectado:

    ```bash
    nmcli -t -f DEVICE,STATE device | grep "^wlan0:"
    ```
  * Fuerza una evaluación:
    `sudo systemctl start fallback-ap@wlan0.service`

* **Uso de otra interfaz (p.ej. `wlan1`):**

  ```bash
  sudo systemctl enable --now fallback-ap@wlan1.timer
  ```

  Ajusta `IFACE` en `/etc/default/fallback-ap` o reinstala con `--iface wlan1`.

* **Conflictos con configuraciones previas:**

  * El instalador ya limpia restos (`wifi-watchdog.service`, scripts antiguos).
  * Asegúrate de no tener otro gestor de red simultáneo (como `dhcpcd` controlando Wi-Fi).

---

## Estructura instalada

```
/usr/local/sbin/fallback-ap.sh               ← Script principal (logs → journald)
/etc/default/fallback-ap                     ← Configuración (SSID, PASS, BAND, CHAN, IFACE, DEBUG)
/etc/systemd/system/fallback-ap@.service     ← Unit plantilla (por interfaz)
/etc/systemd/system/fallback-ap@.timer       ← Timer plantilla (por interfaz)
/etc/NetworkManager/dispatcher.d/50-fallback-ap  ← Hook eventos NM
```

---

## Notas y buenas prácticas

* Para “modo rescate”, 2.4 GHz suele ser más compatible (`--band bg`) y canal 1/6/11 ayuda a evitar interferencias.
* La IP del AP (IPv4 *shared*) suele ser **10.42.0.1**; revisa con `ip a`/`nmcli`.
* Evita cambios muy rápidos de cobertura; el backoff de 30 s reduce *flapping*.
* Si necesitas **más intervalo**, edita `OnUnitActiveSec=` en el timer.
* Si desactivaste `powersave`, recuerda que aumenta el consumo (mejor estabilidad).

---

## Licencia

