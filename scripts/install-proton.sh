#!/usr/bin/env sh
set -e

VERSION="0.9.1"
REVISION="838bf006995325037ce5e2068f64c34469f39df1"

if moon install "moonbit-community/proton_cli@$VERSION" 2>/dev/null; then
  echo "Proton CLI $VERSION installed successfully."
  exit 0
fi

echo "Installing Proton CLI with MoonBit compatibility patch..."
TMP_DIR=$(mktemp -d /tmp/proton-build-XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

git init --quiet "$TMP_DIR"
git -C "$TMP_DIR" fetch --depth=1 https://github.com/moonbit-community/proton.git "$REVISION"
git -C "$TMP_DIR" checkout --quiet FETCH_HEAD

for file in "cefsetup/store/cef_download.mbt" "cli/package/package_updater.mbt"; do
  sed -i '' 's/file\.read_into(buffer)/file.read_into(buffer.mut_view())/g' "$TMP_DIR/$file"
done

moon install "$TMP_DIR/cli"
echo "Proton CLI installed successfully."
