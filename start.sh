#!/bin/sh
set -e

LOCAL_PORT="${LOCAL_PORT:-8080}"
: "${XRAY_UUID:?need XRAY_UUID}"
: "${WS_PATH:?need WS_PATH}"
: "${TUNNEL_TOKEN:?need TUNNEL_TOKEN}"

# platform health port: returns 404, unrelated to the node itself
if [ -n "$PORT" ] && [ "$PORT" != "$LOCAL_PORT" ]; then
  mkdir -p /tmp/empty
  busybox httpd -f -p "0.0.0.0:$PORT" -h /tmp/empty >/dev/null 2>&1 &
fi

cat > /tmp/config.json <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "127.0.0.1",
    "port": ${LOCAL_PORT},
    "protocol": "vless",
    "settings": {"clients": [{"id": "${XRAY_UUID}", "level": 0}], "decryption": "none"},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "${WS_PATH}"}},
    "sniffing": {"enabled": true, "destOverride": ["http", "tls"]}
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}, {"protocol": "blackhole", "tag": "block"}]
}
EOF

xray run -c /tmp/config.json &
XRAY_PID=$!
sleep 3

echo "[xxray] xray pid=${XRAY_PID}, listening 127.0.0.1:${LOCAL_PORT} only"
echo "[xxray] host=${PUBLIC_HOST:-unset} path=${WS_PATH}"

cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" &
CFD_PID=$!
echo "[xxray] cloudflared pid=${CFD_PID}, dialing out to Cloudflare ..."

while kill -0 "$XRAY_PID" 2>/dev/null && kill -0 "$CFD_PID" 2>/dev/null; do
  sleep 5
done

echo "[xxray] a child process exited, stopping the other one"
kill "$XRAY_PID" "$CFD_PID" 2>/dev/null || true
wait 2>/dev/null || true
exit 1
