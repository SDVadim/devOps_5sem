#!/usr/bin/env bash
set -uo pipefail

SYSLOG="${SYSLOG:-/var/log/syslog}"

# проверил, что передали имя сервиса
if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 <service>" >&2
  exit 2
fi
service="$1"

# проверил, что есть нужные утилиты
for cmd in systemctl journalctl grep awk date; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: command '$cmd' not found (нужен Linux с systemd)" >&2
    exit 4
  fi
done

# сделал чтение логов через sudo, если оно есть без пароля
SUDO=""
if [[ $EUID -ne 0 ]] && sudo -n true 2>/dev/null; then
  SUDO="sudo -n"
fi

echo "=== Service: $service"

# проверил, что сервис вообще существует
load_state=$(systemctl show -p LoadState --value "$service" 2>/dev/null)
if [[ "$load_state" != "loaded" ]]; then
  echo "ERROR: service '$service' not found (LoadState=${load_state:-unknown})" >&2
  exit 3
fi

# проверил статус сервиса
status=$(systemctl is-active "$service" 2>/dev/null)
echo "Status: $status"

# если не работает, вывел последние 10 строк лога
exit_code=0
if [[ "$status" != "active" ]]; then
  exit_code=1
  echo "--- Last 10 log lines (journalctl -u $service -n 10):"
  logs=$($SUDO journalctl -u "$service" -n 10 --no-pager 2>/dev/null)
  if [[ -z "$logs" || "$logs" == "-- No entries --" ]]; then
    echo "(log is empty)"
  else
    echo "$logs"
  fi
fi

# посчитал ошибки в syslog за последний час (grep + awk)
echo "--- Errors in $SYSLOG for the last hour:"
if [[ ! -e "$SYSLOG" ]]; then
  echo "WARNING: $SYSLOG not found" >&2
elif ! $SUDO test -r "$SYSLOG"; then
  echo "WARNING: no permission to read $SYSLOG" >&2
else
  cutoff=$(date -d '1 hour ago' '+%Y-%m-%dT%H:%M:%S')

  # сделал поддержку двух форматов времени: 2026-10-15T16:15:01 и Oct 15 16:15:01
  errors=$({ $SUDO grep -i 'error' "$SYSLOG" || true; } | awk -v cutoff="$cutoff" -v year="$(date +%Y)" '
    BEGIN {
      split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
      for (i = 1; i <= 12; i++) mon[names[i]] = sprintf("%02d", i)
    }
    {
      if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) ts = substr($1, 1, 19)
      else if ($1 in mon)                                      ts = sprintf("%s-%s-%02dT%s", year, mon[$1], $2, $3)
      else next
      if (ts >= cutoff) count++
    }
    END { print count + 0 }')
  echo "$errors"
fi

exit "$exit_code"
