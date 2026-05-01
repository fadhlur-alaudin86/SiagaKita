#!/bin/bash
# =============================================================================
# SiagaKita — Script Setup Awal VPS
# Server: Ubuntu 22.04 / Debian 12
# Jalankan sekali saja sebagai root atau user dengan sudo
# =============================================================================

set -e  # Berhenti jika ada perintah yang gagal

echo "======================================"
echo "  SiagaKita VPS Setup"
echo "======================================"

# ── 1. Update sistem ──────────────────────────────────────────────────────────
echo "[1/7] Update sistem..."
apt-get update -y && apt-get upgrade -y

# ── 2. Install Docker ─────────────────────────────────────────────────────────
echo "[2/7] Install Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "Docker terinstall."
else
    echo "Docker sudah ada: $(docker --version)"
fi

# ── 3. Install Docker Compose plugin ─────────────────────────────────────────
echo "[3/7] Verifikasi Docker Compose..."
docker compose version || {
    echo "Docker Compose plugin tidak ditemukan. Install manual..."
    apt-get install -y docker-compose-plugin
}

# ── 4. Buat folder proyek ────────────────────────────────────────────────────
echo "[4/7] Membuat folder /opt/siagakita..."
mkdir -p /opt/siagakita/postgres-data
mkdir -p /opt/siagakita/redis-data

# ── 5. Copy file produksi ke server ──────────────────────────────────────────
echo "[5/7] Copy file docker-compose dan .env..."
echo ""
echo "  LANGKAH MANUAL:"
echo "  Salin file berikut ke /opt/siagakita/ di server ini:"
echo "    1. infrastructure/docker-compose.prod.yml"
echo "    2. infrastructure/.env (isi semua variabel!)"
echo ""
echo "  Contoh dari mesin lokal:"
echo "    scp infrastructure/docker-compose.prod.yml root@139.59.99.230:/opt/siagakita/"
echo "    scp infrastructure/.env root@139.59.99.230:/opt/siagakita/"
echo ""
read -p "  Sudah disalin? Tekan ENTER untuk lanjut..."

# Verifikasi file ada
if [ ! -f /opt/siagakita/.env ]; then
    echo "ERROR: /opt/siagakita/.env tidak ditemukan. Salin dulu!"
    exit 1
fi

if [ ! -f /opt/siagakita/docker-compose.prod.yml ]; then
    echo "ERROR: /opt/siagakita/docker-compose.prod.yml tidak ditemukan."
    exit 1
fi

# ── 6. Jalankan infrastruktur (postgres + redis) ──────────────────────────────
echo "[6/7] Menjalankan PostgreSQL dan Redis..."
cd /opt/siagakita
docker compose -f docker-compose.prod.yml up -d postgres redis

echo "Menunggu PostgreSQL sehat..."
until docker inspect --format='{{.State.Health.Status}}' siagakita_postgres 2>/dev/null | grep -q "healthy"; do
    echo -n "."
    sleep 2
done
echo ""
echo "PostgreSQL siap!"

# ── 7. Jalankan migrasi database ─────────────────────────────────────────────
echo "[7/7] Menjalankan migrasi database (Schema v3)..."
echo ""
echo "  LANGKAH MANUAL:"
echo "  Salin file migrasi ke server:"
echo "    scp backend-go/migrations/003_schema_v3.sql root@139.59.99.230:/opt/siagakita/"
echo ""
read -p "  Sudah disalin? Tekan ENTER untuk menjalankan migrasi..."

if [ -f /opt/siagakita/003_schema_v3.sql ]; then
    source /opt/siagakita/.env
    docker exec -i siagakita_postgres psql \
        -U "$DB_USER" -d "$DB_NAME" \
        < /opt/siagakita/003_schema_v3.sql
    echo "Migrasi selesai!"
    rm /opt/siagakita/003_schema_v3.sql  # Hapus setelah dipakai
else
    echo "PERINGATAN: File migrasi tidak ditemukan. Jalankan manual."
fi

# ── Selesai ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "  Setup selesai!"
echo "======================================"
echo ""
echo "Langkah selanjutnya:"
echo "  1. Daftarkan GitHub Secrets (lihat DEPLOYMENT_GUIDE.md)"
echo "  2. Push ke branch main → GitHub Actions akan deploy backend otomatis"
echo "  3. Cek health: curl http://139.59.99.230:8080/health"
echo ""
echo "Cek log backend:"
echo "  docker logs siagakita_backend -f"
