#!/bin/sh
# Build and smoke-test the libzbar apk on Alpine 3.8 (run as root).
#
# Used by .github/workflows/build.yml through:
#   docker run --rm -v "$PWD:/src" -w /src alpine:3.8 /bin/sh /src/ci/build-in-alpine38.sh
#
# Can also be run directly on an Alpine 3.8 host:
#   sh ci/build-in-alpine38.sh
#
# Output: dist/*.apk plus libzbar-ci.rsa.pub.
#
# Optional environment:
#   ABUILD_PRIVKEY  unencrypted PEM RSA private key used to sign the apk.
#                   When empty, a throwaway key is generated for this build.
set -eu

repo=$(cd "$(dirname "$0")/.." && pwd)
key=/root/.abuild/libzbar-ci.rsa

export PACKAGER="libzbar-apk <libzbar-apk@users.noreply.github.com>"

echo "==> Installing build dependencies"
# Alpine 3.8 images ship a 2018-era CA bundle.  If the HTTPS index update
# fails, retry over HTTP, then install a current ca-certificates for the
# HTTPS downloads done later by abuild (source tarball) and pip (pyzbar).
if ! apk update; then
	sed -i 's|https://|http://|' /etc/apk/repositories
	apk update
fi
apk add --no-cache \
	build-base autoconf automake libtool pkgconf gettext-dev git \
	abuild openssl ca-certificates python3

echo "==> Preparing signing key"
mkdir -p /root/.abuild
touch /root/.abuild/abuild.conf
if [ -n "${ABUILD_PRIVKEY:-}" ]; then
	(umask 077; printf '%s\n' "$ABUILD_PRIVKEY" > "$key")
	chmod 600 "$key"
	openssl rsa -in "$key" -pubout -out "$key.pub" 2>/dev/null
else
	rm -f "$key" "$key.pub"
	abuild-keygen -a -n
	generated=$(ls -t /root/.abuild/*.rsa | head -n 1)
	mv "$generated" "$key"
	mv "$generated.pub" "$key.pub"
fi
chmod 600 "$key"
chmod 644 "$key.pub"
sed -i '/^PACKAGER_PRIVKEY=/d' /root/.abuild/abuild.conf
echo "PACKAGER_PRIVKEY=\"$key\"" >> /root/.abuild/abuild.conf

echo "==> Building apk"
mkdir -p /root/aports/community/libzbar
cp "$repo/APKBUILD" /root/aports/community/libzbar/APKBUILD
# drop packages left over from an earlier build so dist/ only gets this run
mkdir -p /root/packages/community/x86_64
rm -f /root/packages/community/x86_64/libzbar-*.apk
cd /root/aports/community/libzbar
# abuild 3.2.0: -F only affects the parent process; export forceroot so the
# child abuild (package/split phase) also accepts running as root.
export forceroot=1
abuild -F

echo "==> Collecting artifacts"
rm -rf "$repo/dist"
mkdir -p "$repo/dist"
cp /root/packages/community/x86_64/libzbar-*.apk "$repo/dist/"
cp "$key.pub" "$repo/dist/"

echo "==> Installing the built apk and testing pyzbar"
cp "$key.pub" /etc/apk/keys/
apk del libzbar >/dev/null 2>&1 || true
apk verify "$repo"/dist/libzbar-[0-9]*.apk
apk add "$repo"/dist/libzbar-[0-9]*.apk
apk add --no-cache python3
pip3 install --no-cache-dir pyzbar

cd "$repo"
python3 --version
pip3 show pyzbar 2>/dev/null | sed -n '1,3p'
python3 test/test_pyzbar_qr.py

echo "==> Installed package metadata"
apk info -a libzbar | sed -n '1,20p'

echo "==> Artifacts"
ls -l "$repo/dist"
