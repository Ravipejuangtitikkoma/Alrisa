#!/bin/bash
# =============================================================================
# ALRISA CLOUD HUB — AUTO ONLINE TUNNEL (Cloudflare)
# Menjalankan Backend ALRISA dan membuat link HTTPS Publik Internet otomatis
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$DIR/backend_cloud_js"
CLOUDFLARED="$HOME/.local/bin/cloudflared"

if [ ! -f "$CLOUDFLARED" ]; then
    echo "⚠️ Memasang cloudflared..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o "$CLOUDFLARED"
    chmod +x "$CLOUDFLARED"
fi

echo "======================================================================"
echo "🚀 MENYALAKAN ALRISA CLOUD BACKEND (Port 3001)..."
echo "======================================================================"

cd "$BACKEND_DIR"
PORT=3001 node server.js &
SERVER_PID=$!

cleanup() {
    echo ""
    echo "🛑 Menghentikan server ALRISA..."
    kill $SERVER_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

sleep 2

echo "======================================================================"
echo "🌐 MENGHUBUNGKAN KE CLOUDFLARE TUNNEL (HTTPS Publik Tanpa Kartu Kredit)..."
echo "======================================================================"

$CLOUDFLARED tunnel --url http://localhost:3001
