#!/usr/bin/env bash
# Usage: ./run-adapteastore.sh [--rebuild] [--keep-containers]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_DIR="$ROOT_DIR/samples/adaptable-teastore-image"
APP_JAR="$ROOT_DIR/target/JavaBIP-TeaStore-1.0-SNAPSHOT-jar-with-dependencies.jar"
IMAGE_URL="http://localhost:8083/tools.descartes.teastore.image/rest/metrics/requests"
READY_TIMEOUT_S="${READY_TIMEOUT_S:-300}"

REBUILD=false
KEEP=false
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=true ;;
        --keep-containers) KEEP=true ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

for cmd in java javac mvn docker curl git; do
    command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/javac" ]; then
    export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
    echo "==> JAVA_HOME set to $JAVA_HOME"
fi
docker info >/dev/null 2>&1 || { echo "Docker daemon not reachable (try: sudo systemctl start docker)" >&2; exit 1; }

if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
else
    COMPOSE=(docker-compose)
fi
COMPOSE_CMD=("${COMPOSE[@]}" -f "$SAMPLE_DIR/docker-compose.yml" -p adaptable-teastore-image)

cd "$ROOT_DIR"

if $REBUILD; then
    echo "==> Cleaning previous builds"
    mvn -B -q clean
    rm -rf "$SAMPLE_DIR/siphonix-app.jar" "$SAMPLE_DIR/plugins" "$SAMPLE_DIR/scenarios"
fi

if [ ! -d "$HOME/.m2/repository/org/javabip/org.javabip.executor" ] || $REBUILD; then
    echo "==> Installing JavaBIP jars"
    "$ROOT_DIR/install-javabip-jars.sh"
fi

if [ ! -f "$APP_JAR" ]; then
    echo "==> Building the controller"
    mvn -B -q package -DskipTests
fi

echo "==> Starting Adaptable TeaStore + Siphonix + load generator"
"$SAMPLE_DIR/run.debug.sh"

OUTPUT_DIR="$ROOT_DIR/output/adapteastore"

save_load_log() {
    local log_name log_path dest cid
    log_name="$(grep -E '^OUTPUT_LOG=' "$SAMPLE_DIR/.env" | cut -d= -f2-)"
    [ -n "$log_name" ] || return 0
    log_path="$("${COMPOSE_CMD[@]}" exec -T director sh -c "find / -xdev -name '$(basename "$log_name")' -type f 2>/dev/null | head -n 1" | tr -d '\r' || true)"
    if [ -z "$log_path" ]; then
        echo "==> No load generator log ($log_name) found in the director container"
        return 0
    fi
    mkdir -p "$OUTPUT_DIR"
    dest="$OUTPUT_DIR/loadgenerator_$(date +%Y%m%d_%H%M%S)_$(basename "$log_name")"
    cid="$("${COMPOSE_CMD[@]}" ps -q director)"
    docker cp "$cid:$log_path" "$dest" >/dev/null && echo "==> Load generator log saved to $dest"
}

cleanup() {
    save_load_log || true
    if ! $KEEP; then
        echo "==> Stopping containers"
        "${COMPOSE_CMD[@]}" down
    fi
}
trap cleanup EXIT

echo "==> Waiting for the image service ($IMAGE_URL)"
elapsed=0
until curl -sf -o /dev/null "$IMAGE_URL"; do
    if [ "$elapsed" -ge "$READY_TIMEOUT_S" ]; then
        echo "Image service not ready after ${READY_TIMEOUT_S}s. Check: ${COMPOSE_CMD[*]} logs image" >&2
        exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done
echo "==> Image service ready after ${elapsed}s"

echo "==> Starting the adapteastore controller (Ctrl+C to stop)"
java -cp "$APP_JAR" adapteastore.Main || true
