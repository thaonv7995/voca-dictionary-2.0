#!/usr/bin/env sh
# Voca Dictionary — one-line installer for macOS / Linux.
#
#   REPO=<owner>/<repo>
#   curl -fsSL "https://github.com/$REPO/releases/latest/download/install.sh" | sh -s -- "$REPO"
#
# Downloads the latest voca.jar, ensures a PostgreSQL is available (auto via Docker),
# then runs the app in the background on http://localhost:22052.
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

DOWNLOAD="voca.jar.download"
PID_FILE=".voca.pid"

cleanup_download() {
  rm -f "$DOWNLOAD"
}
trap cleanup_download EXIT HUP INT TERM

echo "→ Tải voca.jar (release mới nhất của $REPO) ..."
curl -fL "https://github.com/$REPO/releases/latest/download/voca.jar" -o "$DOWNLOAD"

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

listener_pid=""
if [ -f "$PID_FILE" ]; then
  saved_pid=$(cat "$PID_FILE" 2>/dev/null || true)
  case "$saved_pid" in
    ''|*[!0-9]*) ;;
    *)
      if kill -0 "$saved_pid" 2>/dev/null; then listener_pid="$saved_pid"; fi
      ;;
  esac
fi
if [ -z "$listener_pid" ] && command -v lsof >/dev/null 2>&1; then
  listener_pid=$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true)
elif [ -z "$listener_pid" ] && command -v ss >/dev/null 2>&1; then
  listener_pid=$(ss -ltnp "sport = :$PORT" 2>/dev/null | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' | head -n 1 || true)
fi

if [ -n "$listener_pid" ]; then
  listener_command=$(ps -p "$listener_pid" -o command= 2>/dev/null || true)
  case "$listener_command" in
    *java*"voca.jar"*)
      echo "→ Dừng Voca cũ (PID $listener_pid) ..."
      kill "$listener_pid" 2>/dev/null || true
      attempts=0
      while kill -0 "$listener_pid" 2>/dev/null && [ "$attempts" -lt 15 ]; do
        sleep 1
        attempts=$((attempts + 1))
      done
      if kill -0 "$listener_pid" 2>/dev/null; then
        echo "→ Tiến trình cũ chưa dừng; buộc dừng ..."
        kill -9 "$listener_pid" 2>/dev/null || true
      fi
      ;;
    *)
      echo "✗ Cổng $PORT đang được tiến trình khác sử dụng (PID $listener_pid)." >&2
      echo "  Hãy dừng tiến trình đó hoặc chạy với PORT khác rồi thử lại." >&2
      exit 1
      ;;
  esac
fi

mv "$DOWNLOAD" voca.jar
trap - EXIT HUP INT TERM

if [ -f "voca.log" ]; then mv -f voca.log voca.log.previous; fi
echo "→ Khởi động Voca dưới nền tại http://localhost:$PORT ..."
nohup java -jar voca.jar --server.port="$PORT" > voca.log 2>&1 < /dev/null &
app_pid=$!
echo "$app_pid" > "$PID_FILE"

printf '→ Chờ ứng dụng sẵn sàng '
attempts=0
until curl -fsS "http://127.0.0.1:$PORT/actuator/health" >/dev/null 2>&1; do
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo
    echo "✗ Voca đã dừng khi khởi động. Log gần nhất:" >&2
    tail -n 40 voca.log >&2 || true
    exit 1
  fi
  attempts=$((attempts + 1))
  if [ "$attempts" -ge 60 ]; then
    echo
    echo "✗ Voca chưa sẵn sàng sau 60 giây. Xem log tại $(pwd)/voca.log" >&2
    kill "$app_pid" 2>/dev/null || true
    exit 1
  fi
  printf '.'
  sleep 1
done
echo ' ok'
echo "✓ Voca đang chạy (PID $app_pid): http://localhost:$PORT"
echo "  Log: $(pwd)/voca.log"
echo "  Xem log: tail -f '$(pwd)/voca.log'"
