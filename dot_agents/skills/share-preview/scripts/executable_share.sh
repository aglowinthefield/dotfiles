#!/usr/bin/env bash
# share.sh start <dir> [port]   serve <dir> + an ngrok tunnel with basic auth
# share.sh lan   <dir> [port]   serve <dir> on the LAN only, no tunnel
# share.sh stop  <dir>          stop both, keep files and state
# share.sh status <dir>         print URL, credentials, pids
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cmd="${1:-}"; dir="${2:-}"
[ -n "$cmd" ] && [ -n "$dir" ] || { sed -n 2,5p "$0"; exit 2; }
dir="$(cd "$dir" && pwd)"
share="$dir/.share"
mkdir -p "$share"; chmod 700 "$share"

alive() { [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null; }

start_server() {
  local port="$1"
  if alive "$share/server.pid"; then echo "server already running (port $(cat "$share/port"))"; return; fi
  nohup node "$HERE/server.mjs" "$dir" "$port" >"$share/server.log" 2>&1 &
  echo $! >"$share/server.pid"; echo "$port" >"$share/port"
  timeout 10 sh -c "until grep -q serving '$share/server.log'; do sleep 0.2; done" \
    || { cat "$share/server.log"; exit 1; }
}

start_tunnel() {
  local port; port="$(cat "$share/port")"
  if alive "$share/ngrok.pid"; then return; fi
  [ -f "$share/password" ] || { openssl rand -hex 6 >"$share/password"; chmod 600 "$share/password"; }
  nohup ngrok http "$port" --basic-auth "share:$(cat "$share/password")" \
    --log stdout --log-format logfmt >"$share/ngrok.log" 2>&1 &
  echo $! >"$share/ngrok.pid"
  # ngrok picks its inspector port itself; read the URL from its log.
  timeout 20 sh -c "until grep -q 'url=https' '$share/ngrok.log'; do sleep 0.3; done" \
    || { tail -5 "$share/ngrok.log"; exit 1; }
  grep -o 'url=https://[^ ]*' "$share/ngrok.log" | tail -1 | cut -d= -f2 >"$share/url"
}

status() {
  if alive "$share/server.pid"; then
    grep serving "$share/server.log"
  else
    echo "server: stopped"
  fi
  if alive "$share/ngrok.pid"; then
    echo "public: $(cat "$share/url")  user: share  password: $(cat "$share/password")"
  else
    echo "tunnel: off"
  fi
}

case "$cmd" in
  start) start_server "${3:-4321}"; start_tunnel; status ;;
  lan) start_server "${3:-4321}"; status ;;
  stop)
    for p in ngrok server; do
      alive "$share/$p.pid" && kill "$(cat "$share/$p.pid")" && echo "stopped $p"
      rm -f "$share/$p.pid"
    done ;;
  status) status ;;
  *) sed -n 2,5p "$0"; exit 2 ;;
esac
