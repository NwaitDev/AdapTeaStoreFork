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
    COMPOSE="docker compose"
else
    COMPOSE="docker-compose"
fi
COMPOSE_CMD="$COMPOSE -f $SAMPLE_DIR/docker-compose.yml -p adaptable-teastore-image"

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

cleanup() {
    if ! $KEEP; then
        echo "==> Stopping containers"
        $COMPOSE_CMD down
    fi
}
trap cleanup EXIT

echo "==> Waiting for the image service ($IMAGE_URL)"
elapsed=0
until curl -sf -o /dev/null "$IMAGE_URL"; do
    if [ "$elapsed" -ge "$READY_TIMEOUT_S" ]; then
        echo "Image service not ready after ${READY_TIMEOUT_S}s. Check: $COMPOSE_CMD logs image" >&2
        exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
done
echo "==> Image service ready after ${elapsed}s"

echo "==> Starting the adapteastore controller (Ctrl+C to stop)"
java -cp "$APP_JAR" adapteastore.Main || true
