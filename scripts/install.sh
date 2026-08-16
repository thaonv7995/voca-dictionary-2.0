#!/usr/bin/env sh
# Voca Dictionary — one-line installer for macOS / Linux.
#
#   REPO=<owner>/<repo>
#   curl -fsSL "https://github.com/$REPO/releases/latest/download/install.sh" | sh -s -- "$REPO"
#
# Downloads the latest voca.jar, ensures a PostgreSQL is available (auto via Docker),
# then runs the app on http://localhost:22052.
set -eu

REPO="${1:-${VOCA_REPO:-}}"
if [ -z "$REPO" ]; then
  echo "Usage: ... | sh -s -- <github-owner>/<repo>   (or set VOCA_REPO)" >&2
  exit 1
fi
DIR="${VOCA_DIR:-voca}"
PORT="${PORT:-22052}"

mkdir -p "$DIR"
cd "$DIR"

echo "→ Tải voca.jar (release mới nhất của $REPO) ..."
curl -fL "https://github.com/$REPO/releases/latest/download/voca.jar" -o voca.jar

if ! command -v java >/dev/null 2>&1; then
  echo "✗ Chưa có Java. Cài JDK 21+ (vd: 'brew install openjdk@21', hoặc apt/dnf) rồi chạy lại." >&2
  exit 1
fi

# PostgreSQL trên :5432 — tự dựng bằng Docker nếu chưa có container 'voca-db'.
if command -v docker >/dev/null 2>&1; then
  if docker ps -a --format '{{.Names}}' | grep -q '^voca-db$'; then
    docker start voca-db >/dev/null 2>&1 || true
  else
    echo "→ Dựng PostgreSQL (docker: voca-db) ..."
    docker run -d --name voca-db \
      -e POSTGRES_USER=voca -e POSTGRES_PASSWORD=voca -e POSTGRES_DB=voca \
      -p 5432:5432 postgres:16 >/dev/null
  fi
  printf '→ Chờ DB sẵn sàng '
  until docker exec voca-db pg_isready -U voca >/dev/null 2>&1; do printf '.'; sleep 1; done
  echo ' ok'
else
  echo "! Không thấy Docker. Hãy đảm bảo có PostgreSQL (db=voca user=voca pass=voca) trên :5432."
fi

echo "→ Khởi động Voca tại http://localhost:$PORT (Ctrl+C để dừng) ..."
exec java -jar voca.jar
