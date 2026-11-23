#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$ROOT_DIR/samples/adaptable-teastore-image"
SIPHONIX_REPO="${SIPHONIX_REPO:-https://github.com/brice10/siphonix.git}"
SIPHONIX_REF="${SIPHONIX_REF:-72051a0}"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Cloning Siphonix ($SIPHONIX_REF)"
git clone -q "$SIPHONIX_REPO" "$WORK_DIR/siphonix"
git -C "$WORK_DIR/siphonix" checkout -q "$SIPHONIX_REF"

echo "==> Building Siphonix"
(cd "$WORK_DIR/siphonix" && mvn -B -q clean package -DskipTests)

echo "==> Copying artifacts to $TARGET_DIR"
cp "$WORK_DIR"/siphonix/siphonix-runtime/target/*-jar-with-dependencies.jar "$TARGET_DIR/siphonix-app.jar"
mkdir -p "$TARGET_DIR/plugins" "$TARGET_DIR/scenarios"
cp "$WORK_DIR"/siphonix/siphonix-plugins/adaptiflow-engine-plugin/target/*-jar-with-dependencies.jar \
   "$TARGET_DIR/plugins/adaptiflow-engine-plugin.jar"
cp "$WORK_DIR"/siphonix/samples/adaptiflow-yaml-scenarios/scenarios/*.yml "$TARGET_DIR/scenarios/"

echo "==> Done"
