#!/bin/sh
set -e

# Directory of this script
SSL_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SSL_DIR/cert.pem" ] && [ -f "$SSL_DIR/key.pem" ]; then
    echo "SSL certificate and key already exist in $SSL_DIR"
    exit 0
fi

echo "Generating self-signed SSL certificate for local / fallback testing..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$SSL_DIR/key.pem" \
    -out "$SSL_DIR/cert.pem" \
    -subj "/C=ID/ST=Aceh/L=Banda Aceh/O=SiagaKita/OU=Infra/CN=api.siagakita.com"

chmod 600 "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"

echo "✅ Self-signed SSL certificate generated at $SSL_DIR"
