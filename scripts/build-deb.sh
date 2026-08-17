#!/usr/bin/env bash
set -euo pipefail

version=7.8.0
source_sha256=38fd1a7d1b558c55756e1436bd58e7d6fd46eb0271319a4af2113a6188e1857b
source_url="https://open.u-tools.cn/download/utools_${version}_amd64.deb"
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source_deb=${1:-"$repo_root/utools_${version}_amd64.deb"}
output_dir=${2:-"$repo_root/outputs"}

if [[ ! -f "$source_deb" ]]; then
  curl --fail --location --retry 3 --output "$source_deb" "$source_url"
fi

printf '%s  %s\n' "$source_sha256" "$source_deb" | sha256sum --check --status || {
  echo "Official deb SHA-256 mismatch: $source_deb" >&2
  exit 1
}

build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
dpkg-deb -R "$source_deb" "$build_dir/root"

node "$repo_root/patch-native.js" \
  "$build_dir/root/opt/uTools/resources/app.asar.unpacked/node_modules/addon/linux-x64.node"

sed -i 's/^Package: utools$/Package: utools-wayland/' "$build_dir/root/DEBIAN/control"
sed -i 's/^Version: 7\.8\.0$/Version: 7.8.0+waylandfix1/' "$build_dir/root/DEBIAN/control"
sed -i '/^Conflicts:/d;/^Replaces:/d;/^Provides:/d' "$build_dir/root/DEBIAN/control"
sed -i '/^Version:/a Provides: utools\nConflicts: utools\nReplaces: utools' "$build_dir/root/DEBIAN/control"
rm -f "$build_dir/root/DEBIAN/md5sums"

mkdir -p "$output_dir"
output="$output_dir/utools-wayland_${version}+waylandfix1_amd64.deb"
dpkg-deb --root-owner-group --build "$build_dir/root" "$output"
sha256sum "$output"
