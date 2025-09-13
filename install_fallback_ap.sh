#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
#  RPi Fallback AP Installer
# =========================
# Uso:
#   sudo bash install_fallback_ap.sh --iface wlan0 --ssid GNSS --pass 12345678 --band bg --chan 6 --force
# Opciones:
#   --iface IFACE            (default: wlan0)
#   --ssid  SSID             (default: GNSS)
#   --pass  PSK              (8..63 chars; default: 12345678)
#   --band  bg|a             (default: bg)
#   --chan  N                (default: 6)
#   --no-powersave-tweak     (no toca wifi.powersave)
#   --force                  (lanza evaluación inicial ahora)
#   --status                 (muestra estado servicio/timer y conexiones)
#   --uninstall              (desinstala todo)

# -------- Parámetros --------
IFACE="wlan0"
SSID="GNSS"
PASS="12345678"
BAND="bg"
CHAN="6"
POWERSAVE=1
MODE="install"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iface) IFACE="$2"; shift 2;;
    --ssid)  SSID="$2"; shift 2;;
    --pass|--psk) PASS="$2"; shift 2;;
    --band)  BAND="$2"; shift 2;;
    --chan|--channel) CHAN="$2"; shift 2;;
    --no-powersave-tweak) POWERSAVE=0; shift;;
    --force) FORCE=1; shift;;
    --status) MODE="status"; shift;;
    --uninstall) MODE="uninstall"; shift;;
    -h|--help) sed -n '1,120p' "$0"; exit 0;;
    *) echo "Opción no reconocida: $1" >&2; exit 1;;
  esac
done

need_root() { [[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"; }
log() { echo -e "[*] $*"; }
ok()  { echo -e "[✓] $*"; }
warn(){ echo -e "[!] $*" >&2; }
die() { echo -e "[x] $*" >&2; exit 1; }

need_root "$@"

case "$MODE" in
  status)
    systemctl status "fallback-ap@${IFACE}.service" --no-pager || true
    echo
    systemctl status "fallback-ap@${IFACE}.timer"   --no-pager || true
    echo
    nmcli -g NAME,TYPE,DEVICE,GENERAL.STATE con show --active 2>/dev/null || true
    exit 0
    ;;
  uninstall)
    log "Desinstalando unidades/archivos…"
    systemctl disable --now "fallback-ap@${IFACE}.timer"   2>/dev/null || true
    systemctl disable --now "fallback-ap@${IFACE}.service" 2>/dev/null || true
    # limpia cualquier timer antiguo no-plantilla
    systemctl disable --now fallback-ap.timer 2>/dev/null || true
    rm -f /etc/systemd/system/fallback-ap.timer 2>/dev/null || true

    rm -f /usr/local/sbin/fallback-ap.sh
    rm -f /etc/systemd/system/fallback-ap@.service
    rm -f /etc/systemd/system/fallback-ap@.timer
    rm -f /etc/NetworkManager/dispatcher.d/50-fallback-ap
    rm -f /etc/default/fallback-ap
    systemctl daemon-reload
    ok "Desinstalado."
    exit 0
    ;;
esac

# Validaciones simples
[[ ${#PASS} -ge 8 && ${#PASS} -le 63 ]] || die "La clave --pass debe tener entre 8 y 63 caracteres."
[[ "$BAND" =~ ^(bg|a)$ ]] || die "--band debe ser 'bg' (2.4GHz) o 'a' (5GHz)."
[[ "$CHAN" =~ ^[0-9]+$ ]] || die "--chan debe ser un número."

# -------- Dependencias --------
if ! command -v nmcli >/dev/null 2>&1; then
  log "Instalando NetworkManager…"
  apt-get update -y
  apt-get install -y network-manager
  systemctl enable --now NetworkManager
fi

# -------- Limpieza restos antiguos --------
log "Limpiando restos previos…"
systemctl disable --now wifi-watchdog.service 2>/dev/null || true
rm -f /etc/systemd/system/wifi-watchdog.service 2>/dev/null || true
rm -f /usr/local/bin/wifi-watchdog.sh          2>/dev/null || true
rm -f /etc/NetworkManager/dispatcher.d/99-fallback 2>/dev/null || true
# timer viejo no-plantilla (si lo hubiera)
systemctl disable --now fallback-ap.timer 2>/dev/null || true
rm -f /etc/systemd/system/fallback-ap.timer 2>/dev/null || true

# -------- Config por defecto --------
log "Escribiendo /etc/default/fallback-ap"
install -o root -g root -m 0644 /dev/null /etc/default/fallback-ap
cat >/etc/default/fallback-ap <<CFG
# Configuración del AP de emergencia (NetworkManager)
SSID="${SSID}"
PASS="${PASS}"
BAND="${BAND}"
CHAN="${CHAN}"
IFACE="${IFACE}"
CFG

# -------- Script principal --------
log "Instalando /usr/local/sbin/fallback-ap.sh"
install -o root -g root -m 0755 /dev/null /usr/local/sbin/fallback-ap.sh
cat >/usr/local/sbin/fallback-ap.sh <<'SCRIPT'
#!/usr/bin/env bash
# Nota: quitamos -e para que ningún fallo “blando” tumbe el servicio.
set -uo pipefail
# → Log al journal con preferencia por systemd-cat; si no, usa logger.
if command -v systemd-cat >/dev/null 2>&1; then
  exec 1> >(/usr/bin/systemd-cat -t fallback-ap -p info) 2>&1
elif command -v logger >/dev/null 2>&1; then
  exec 1> >(logger -t fallback-ap) 2>&1
fi

CFG="/etc/default/fallback-ap"
STATE_DIR="/run/fallback-ap"
mkdir -p "$STATE_DIR"

SSID="GNSS"; PASS="12345678"; BAND="bg"; CHAN="6"; IFACE="wlan0"
[ -r "$CFG" ] && . "$CFG"
IFACE="${1:-$IFACE}"

# nmcli “suave”: nunca rompe el script si falla
nmq() { nmcli "$@" 2>/dev/null || return 0; }

echo "fallback-ap: start iface=$IFACE ssid=$SSID band=$BAND chan=$CHAN"

rfkill unblock wifi 2>/dev/null || true
nmq radio wifi on
nmq dev set "$IFACE" managed yes

# Perfil AP idempotente
if ! nmq -g NAME con show | grep -Fxq "fallback-ap"; then
  echo "fallback-ap: creando perfil AP"
  nmq con add type wifi ifname "$IFACE" con-name "fallback-ap" ssid "$SSID"
  nmq con modify "fallback-ap" 802-11-wireless.mode ap \
                                802-11-wireless.band "$BAND" \
                                802-11-wireless.channel "$CHAN"
  nmq con modify "fallback-ap" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASS"
  nmq con modify "fallback-ap" connection.autoconnect no \
                               ipv4.method shared \
                               ipv6.method ignore
fi

now=$(date +%s)
last_ts_file="$STATE_DIR/last-switch.ts"
last_mode_file="$STATE_DIR/last-mode.txt"
last_ts=$( [ -f "$last_ts_file" ] && cat "$last_ts_file" || echo 0 )
since=$((now - last_ts))
min_interval=30

# Estado del dispositivo (si nmcli no reporta, deja 'unknown')
current_state="$(nmq -t -f DEVICE,STATE device | awk -F: -v d="$IFACE" '$1==d{print $2}')"
current_state="${current_state:-unknown}"
echo "fallback-ap: $IFACE state=$current_state since_last_switch=${since}s"

# Conexiones Wi-Fi conocidas (sin mirar autoconnect, más compatible)
mapfile -t KNOWN <<< "$(nmq -t -f NAME,TYPE con show | awk -F: '$2=="wifi" && $1!="fallback-ap"{print $1}')"

# ¿Qué conexión está activa en esta interfaz?
active_name="$(nmq -t -f NAME,DEVICE con show --active | awk -F: -v d="$IFACE" '$2==d{print $1}')"
echo "fallback-ap: active_name=${active_name:-none}"

# Si estamos con el AP activo y hay redes conocidas, intenta migrar a cliente
if [ "$active_name" = "fallback-ap" ] && [ "${#KNOWN[@]}" -gt 0 ]; then
  nmq --wait 10 dev wifi rescan
  for n in "${KNOWN[@]}"; do
    [ -n "$n" ] || continue
    echo "fallback-ap: migrando AP→cliente con $n"
    if nmcli --wait 20 con up id "$n" ifname "$IFACE" 2>/dev/null; then
      echo "fallback-ap: migrado a cliente ($n)"
      echo client >"$last_mode_file"; echo "$now" >"$last_ts_file"
      exit 0
    fi
  done
  echo "fallback-ap: no se pudo migrar; sigo en AP"
  exit 0
fi

# Si no está conectado como cliente, intenta redes conocidas
if [ "$current_state" != "connected" ] && [ "${#KNOWN[@]}" -gt 0 ]; then
  nmq --wait 10 dev wifi rescan
  for n in "${KNOWN[@]}"; do
    [ -n "$n" ] || continue
    echo "fallback-ap: intentando cliente → $n"
    if nmcli --wait 15 con up id "$n" ifname "$IFACE" 2>/dev/null; then
      echo "fallback-ap: conectado como cliente a $n"
      echo client >"$last_mode_file"; echo "$now" >"$last_ts_file"
      exit 0
    fi
  done
fi

# Si no hay cliente, levanta AP (con backoff para no aletear)
if [ "$current_state" != "connected" ]; then
  if [ "$since" -lt "$min_interval" ] && [ "${2:-}" != "--force" ]; then
    echo "fallback-ap: backoff, último cambio hace ${since}s"
    exit 0
  fi
  echo "fallback-ap: subiendo AP \"$SSID\""
  nmq -t -f NAME con show --active | grep -qx "fallback-ap" \
    || nmcli --wait 15 con up "fallback-ap" ifname "$IFACE" 2>/dev/null || true
  echo ap >"$last_mode_file"; echo "$now" >"$last_ts_file"
fi

echo "fallback-ap: done"
exit 0
SCRIPT
chmod +x /usr/local/sbin/fallback-ap.sh


# -------- Units systemd --------
log "Instalando unidades systemd"

# Service plantilla (sin [Install]; no se habilita, solo se arranca)
cat >/etc/systemd/system/fallback-ap@.service <<'UNIT'
[Unit]
Description=Fallback AP manager for %I (cliente→AP si no hay Wi-Fi conocida)
After=NetworkManager.service
Wants=NetworkManager.service

[Service]
Type=oneshot
EnvironmentFile=-/etc/default/fallback-ap
ExecStart=/usr/local/sbin/fallback-ap.sh %I
RemainAfterExit=yes
SyslogIdentifier=fallback-ap
UNIT

# Timer plantilla por interfaz
cat >/etc/systemd/system/fallback-ap@.timer <<'TIMER'
[Unit]
Description=Revisión periódica de Wi-Fi conocida / cambio AP (%i)

[Timer]
OnBootSec=20
OnActiveSec=90
AccuracySec=5s
Persistent=true
Unit=fallback-ap@%i.service

[Install]
WantedBy=timers.target
TIMER

# -------- Dispatcher NM --------
log "Instalando hook dispatcher de NetworkManager"
install -o root -g root -m 0755 /dev/null /etc/NetworkManager/dispatcher.d/50-fallback-ap
cat >/etc/NetworkManager/dispatcher.d/50-fallback-ap <<'HOOK'
#!/bin/sh
CFG="/etc/default/fallback-ap"
IFACE_EV="$1"
ACTION="$2"

# interfaz objetivo desde config (o wlan0 si falta)
IFACE_CFG="$(awk -F= '/^IFACE=/{gsub(/"/,"",$2);print $2}' "$CFG" 2>/dev/null)"
[ -n "$IFACE_CFG" ] || IFACE_CFG="wlan0"

[ "$IFACE_EV" = "$IFACE_CFG" ] || exit 0

case "$ACTION" in
  up|down|pre-up|pre-down|dhcp4-change|dhcp6-change|connectivity-change|hostname)
    /bin/systemctl start "fallback-ap@${IFACE_EV}.service"
    ;;
esac
HOOK

# -------- Powersave tweak (opcional) --------
if [[ "$POWERSAVE" -eq 1 ]]; then
  log "Desactivando ahorro de energía Wi-Fi (wifi.powersave=2)"
  mkdir -p /etc/NetworkManager/conf.d
  cat >/etc/NetworkManager/conf.d/wifi-powersave.conf <<'PS'
[connection]
wifi.powersave = 2
PS
  systemctl restart NetworkManager || true
fi

# -------- Enable/Start correcto --------
log "Habilitando timer por interfaz y lanzando evaluación inicial…"
systemctl daemon-reload
systemctl enable --now "fallback-ap@${IFACE}.timer"

sleep 2
if ! systemctl start "fallback-ap@${IFACE}.service"; then
  echo "[!] Primer arranque falló (posible carrera con NetworkManager). Reintento en 5s…"
  sleep 5
  systemctl start "fallback-ap@${IFACE}.service" || true
fi

if [[ "$FORCE" -eq 1 ]]; then
  log "Evaluación inicial (forzada)…"
  /usr/local/sbin/fallback-ap.sh "$IFACE" --force || true
fi

ok "Instalación completa.
  • Config:        /etc/default/fallback-ap
  • Script:        /usr/local/sbin/fallback-ap.sh
  • Service:       fallback-ap@${IFACE}.service   (no se habilita, sólo se arranca)
  • Timer:         fallback-ap@${IFACE}.timer     (habilitado)
  • Dispatcher:    /etc/NetworkManager/dispatcher.d/50-fallback-ap

Comandos útiles:
  systemctl status fallback-ap@${IFACE}.timer --no-pager
  systemctl status fallback-ap@${IFACE}.service --no-pager
  journalctl -t fallback-ap -n 100 -f
"
