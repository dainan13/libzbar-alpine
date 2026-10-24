# Maintainer: libzbar-apk <libzbar-apk@users.noreply.github.com>
#
# Minimal libzbar build for Alpine 3.8 (musl / gcc 6.4).
#
# Only the shared library (libzbar.so.0), its headers and pkg-config file
# are built.  zbarimg/zbarcam are intentionally omitted: zbarimg needs
# ImageMagick and neither is required by python-pyzbar, which loads
# libzbar.so.0 through ctypes.
#
# pkgrel uses the build date (YYYYMMDD): apk renders it as
# 0.23.93-r20261024, so rebuilds stay ordered without bumping pkgver.
pkgname=libzbar
pkgver=0.23.93
pkgrel=20261024
pkgdesc="Bar code reader shared library (libzbar.so.0), used by pyzbar"
url="https://github.com/mchehab/zbar"
arch="all"
license="LGPL-2.0-or-later"
depends=""
makedepends="autoconf automake libtool pkgconf gettext-dev"
subpackages="$pkgname-dev $pkgname-doc"
source="https://deb.debian.org/debian/pool/main/z/zbar/zbar_${pkgver}.orig.tar.gz"
builddir="$srcdir/zbar-$pkgver"
sha256sums="212dfab527894b8bcbcc7cd1d43d63f5604a07473d31a5f02889e372614ebe28  zbar_0.23.93.orig.tar.gz"

# The Debian orig tarball is the pristine upstream 0.23.93 release and,
# unlike the GitHub archive, does not contain a pre-generated configure
# script, so autoreconf is run in prepare().
prepare() {
	cd "$builddir"
	autoreconf -fi
}

build() {
	cd "$builddir"
	./configure \
		--build=$CBUILD \
		--host=$CHOST \
		--prefix=/usr \
		--sysconfdir=/etc \
		--mandir=/usr/share/man \
		--localstatedir=/var \
		--disable-static \
		--enable-shared \
		--disable-video \
		--disable-doc \
		--disable-nls \
		--without-gtk \
		--without-qt \
		--without-qt6 \
		--without-python \
		--without-java \
		--without-imagemagick \
		--without-graphicsmagick \
		--without-dbus \
		--without-xshm \
		--without-xv \
		--without-npapi \
		--without-gir \
		--without-jpeg
	make
}

package() {
	cd "$builddir"
	make DESTDIR="$pkgdir" install

	# libtool archives and static libs are not shipped
	find "$pkgdir" -name '*.la' -delete
	rm -f "$pkgdir"/usr/lib/*.a

	# no tools are built (zbarimg would need ImageMagick), drop empty bin dir
	rmdir "$pkgdir"/usr/bin 2>/dev/null || true
}

dev() {
	default_dev
}

doc() {
	default_doc
}
