#!/usr/bin/env bash

#script mostly taken from https://github.com/openstenoproject/plover/blob/v4.0.0.dev1/linux/appimage.sh

set -e

APP=Mitmproxy
VERSION=2.0.2
LOWERAPP=$(echo $APP | tr '[:upper:]' '[:lower:]')
topdir="$PWD"
distdir="$topdir/dist"
builddir="$topdir/build/appimage"
appdir="$builddir/$APP.AppDir"
cachedir="$topdir/.cache/appimage"
downloads="$topdir/.cache/downloads"

rm -rf "$builddir"
mkdir -p "$appdir" "$cachedir" "$distdir" "$downloads"

# set ARCH
set_arch()
{
  BIN=$(find . -name *.so* -type f | head -n 1)
  INFO=$(file "$BIN")
  if [ -z $ARCH ] ; then
    if [[ $INFO == *"x86-64"* ]] ; then
      ARCH=x86_64
    elif [[ $INFO == *"i686"* ]] ; then
      ARCH=i686
    elif [[ $INFO == *"armv6l"* ]] ; then
      ARCH=armhf
    else
      echo "Could not automatically detect the architecture."
      echo "Please set the \$ARCH environment variable."
     exit 1
    fi
  fi
}

# Get dependencies on the target system
apt-get update \
    && apt-get -y --no-install-recommends install ca-certificates \
    curl \
    fuse \
    g++ \
    gcc \
    libbz2-dev \
    libffi-dev \
    libgdbm-dev \
    libglib2.0-0 \
    libncurses5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    python2.7 \
    wget \
    && rm -rf /var/lib/apt/lists/*

ln -sf /usr/bin/python2.7 /usr/bin/python2
ln -s /usr/bin/gpg /usr/bin/gpg2

# Source some helper functions
wget -q https://github.com/probonopd/AppImageKit/releases/download/8/appimagetool-x86_64.AppImage -O "$cachedir/appimagetool"
wget -q https://github.com/probonopd/AppImageKit/releases/download/6/AppImageAssistant_6-x86_64.AppImage -O  "$cachedir/appimageassistant"
wget -q https://github.com/probonopd/AppImages/raw/master/functions.sh -O "$cachedir/functions.sh"
wget -q https://www.python.org/ftp/python/3.5.3/Python-3.5.3.tgz -O "$downloads/Python-3.5.3.tgz"

# Build Python 3.5
tar xf "$downloads/Python-3.5.3.tgz" -C "$builddir"
cd "$builddir/Python-3.5.3"
  ./configure \
  --cache-file="$cachedir/python.config.cache" \
  --prefix="$appdir/usr" \
  --enable-ipv6 \
  --enable-loadable-sqlite-extensions \
  --enable-shared \
  --with-threads \
  --without-ensurepip
make
make install >/dev/null

# Install app and dependencies inside the AppDir
appdir_python()
{
  env LD_LIBRARY_PATH="$appdir/usr/lib" "$appdir/usr/bin/python3.5" -s "$@"
}
appdir_pip()
{
  env LD_LIBRARY_PATH="$appdir/usr/lib" "$appdir/usr/bin/pip3" "$@"
}
python='appdir_python'
pip='appdir_pip'

wget -q https://bootstrap.pypa.io/get-pip.py
"$python" "get-pip.py"

# Install app and dependencies
"$pip" install $LOWERAPP==$VERSION

sed -i "s/^#\!.*$/#\!\/usr\/bin\/env python3/" $appdir/usr/bin/*

cat > "$appdir/$LOWERAPP.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP
Exec=$LOWERAPP
Icon=$LOWERAPP
Categories=Utility;Network
Comment=An interactive TLS-capable intercepting HTTP proxy for penetration testers and software developers
EOF

cp $topdir/linux/$LOWERAPP.png "$appdir/$LOWERAPP.png"

# Finalize AppDir.
(
  . "$cachedir/functions.sh"
  cd "$appdir"
  # Add AppRun
  get_apprun
  # Add desktop integration.
  get_desktopintegration $LOWERAPP
  # Fix missing system dependencies.
  copy_deps; copy_deps; copy_deps
  move_lib
  # Move usr/include out of the way to preserve usr/include/python3.5m.
  mv usr/include usr/include.tmp
  delete_blacklisted
  mv usr/include.tmp usr/include
)

# Strip binaries.
strip_binaries()
{
  chmod u+w -R "$appdir"
#  {
#    printf '%s\0' "$appdir/usr/bin/python3.5"
#    find "$appdir" -type f -regex '.*\.so\(\.[0-9.]+\)?$' -print0
#  } | xargs -0 --no-run-if-empty --verbose -n1 strip
}
#strip_binaries

# Remove empty directories.
remove_emptydirs()
{
  find "$appdir" -type d -empty -print0 | xargs -0 --no-run-if-empty rmdir -vp --ignore-fail-on-non-empty
}
remove_emptydirs

. "$cachedir/functions.sh"
cd "$builddir"
GLIBC_NEEDED=${GLIBC_NEEDED:=$(glibc_needed)}
set_arch
appimage="$distdir/$APP-$VERSION.glibc${GLIBC_NEEDED}-$ARCH.AppImage"

# Create image with generate_appimage
#generate_appimage
#if [ -d /image ]; then
#  cp -p $topdir/build/out/* /image/
#fi

# Create image with appimageassistant
#chmod +x "$cachedir/appimageassistant"
#"$cachedir/appimageassistant" "$appdir" "$appimage"

# Create image with appimagetool
# Note: extract appimagetool so fuse is not needed.
chmod +x "$cachedir/appimagetool"
"$cachedir/appimagetool" --appimage-extract
env VERSION="$VERSION" ./squashfs-root/AppRun --no-appstream --verbose "$appdir" "$appimage"

#Useful when running inside docker.
if [ -d /image ]; then
  cp -p "$appimage" /image/
fi
