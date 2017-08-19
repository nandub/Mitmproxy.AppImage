#!/usr/bin/env bash

#script mostly taken from https://github.com/openstenoproject/plover/blob/v4.0.0.dev1/linux/appimage.sh

set -e

. ./utils/functions.sh

export HOME=/root

APP=Mitmproxy
LOWERAPP=$(echo $APP | tr '[:upper:]' '[:lower:]')
topdir="$PWD"
distdir="$topdir/dist"
builddir="$topdir/build/appimage"
appdir="$builddir/$APP.AppDir"
cachedir="$topdir/.cache/appimage"
downloads="$topdir/.cache/downloads"
python='python2'
make_opts=(-s)
opt_ccache=0
opt_optimize=0

parse_opts args "$@"
set -- "${args[@]}"

while [ $# -ne 0 ]
do
  case "$1" in
    -O)
      opt_optimize=1
      ;;
    -c|--ccache)
      opt_ccache=1
      ;;
    -j|--jobs)
      make_opts+=("-j$2")
      shift
      ;;
    -p|--python)
      python="$2"
      shift
      ;;
    -*)
      err "invalid option: $1"
      exit 1
      ;;
  esac
  shift
done

compile_openssl()
{
    OPENSSL_VERSION="1.0.2"
    wget -q --no-check-certificate https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz -O "$downloads/openssl-${OPENSSL_VERSION}.tar.gz"
    tar xf "$downloads/openssl-${OPENSSL_VERSION}.tar.gz" -C "$builddir"
    pushd "$builddir/openssl-${OPENSSL_VERSION}"
    ./config -Wl,--version-script="$topdir/linux/openssl.ld" -Wl,-Bsymbolic-functions -fPIC shared no-ssl2 no-ssl3 -fPIC --prefix="$appdir/usr"
    make && make install
    popd
}

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

run apt-get update \
    && run apt-get -y --no-install-recommends install ca-certificates \
    curl \
    file \
    g++ \
    gcc \
    libbz2-dev \
    libgdbm-dev \
    libglib2.0-0 \
    liblzma-dev \
    libncurses5-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    python \
    wget

if ! which python2 > /dev/null; then
    run ln -s /usr/bin/python2.* /usr/bin/python2
fi
if ! which gpg2 > /dev/null; then
    run ln -s /usr/bin/gpg /usr/bin/gpg2
fi

run rm -rf "$builddir"
run mkdir -p "$appdir" "$cachedir" "$distdir" "$downloads"

# Source some helper functions
run wget -q --no-check-certificate https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O "$cachedir/appimagetool"
run wget -q --no-check-certificate https://www.python.org/ftp/python/3.5.3/Python-3.5.3.tgz -O "$downloads/Python-3.5.3.tgz"
run wget -q --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O "$downloads/get-pip.py"
run cp "$topdir/linux/functions.sh" "$cachedir/functions.sh"

if [ $opt_ccache -ne 0 ]
then
   run export CCACHE_DIR="$topdir/.cache/ccache" CCACHE_BASEDIR="$buildir" CC='ccache gcc'
fi

# Compile custom openssl.
if [ -f /usr/bin/lsb_release ]; then
  name=$(lsb_release -a | grep Codename | awk '{ print $2 }')
  if [ "$name" = "lucid" ]; then
      run apt-get -y --no-install-recommends install zfs-fuse
      if [ -d $HOME/debs ]; then
          run $HOME/debs/backport-precise-libs.sh
      fi
      run compile_openssl
  else
      run apt-get -y --no-install-recommends install fuse
  fi
fi
run rm -rf /var/lib/apt/lists/*

# Install app and dependencies inside the AppDir
appdir_cmd()
{
    export CFLAGS="-I$appdir/usr/include"
    export LDFLAGS="-L$appdir/usr/lib"
    export LD_LIBRARY_PATH="$appdir/usr/lib" 
    "$@"
}

# Build Python 3.5
info '('
(
run tar xf "$downloads/Python-3.5.3.tgz" -C "$builddir"
run cd "$builddir/Python-3.5.3"
cmd=(
  ./configure
  --cache-file="$cachedir/python.config.cache"
  --prefix="$appdir/usr"
  --enable-ipv6
  --enable-loadable-sqlite-extensions
  --enable-shared
  --with-threads
  --without-ensurepip
)
if [ $opt_optimize -ne 0 ]
then
  cmd+=(--enable-optimizations)
fi
run appdir_cmd "${cmd[@]}"
run appdir_cmd make "${make_opts[@]}"
run appdir_cmd make "${make_opts[@]}" install >/dev/null
)
info ')'

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

# Install pip/wheel...
run "$python" "$downloads/get-pip.py" -f "$wheels"
# ...and cache them for the next iteration.
run wheels_install --no-install pip wheel

# Install app and dependencies
run "$pip" download -d "$wheels" -f "$wheels" --no-binary :all: cryptography
run "$pip" download -d "$wheels" -f "$wheels" $LOWERAPP
run "$pip" install -f "$wheels" --no-binary :all: cryptography
run "$pip" install -f "$wheels" $LOWERAPP

VERSION=$("$pip" show $LOWERAPP | grep Version | awk '{ print $2 }')

# List installed Python packages.
run "$python" -m pip list --format=columns

# Trim the fat.
run "$python" -m utils.trim "$appdir" "$topdir/linux/appimage_blacklist.txt"

# Make distribution source-less.
run "$python" -m utils.source_less "$appdir/usr/lib/python3.5" '*/pip/_vendor/distlib/*'

run sed -i "s/^#\!.*$/#\!\/usr\/bin\/env python3.5/" $appdir/usr/bin/*

create_desktop()
{
  cat > "$appdir/$LOWERAPP.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP
Exec=$LOWERAPP
Icon=$LOWERAPP
Categories=Utility;Network
Comment=An interactive TLS-capable intercepting HTTP proxy for penetration testers and software developers
EOF
}
run create_desktop

run cp $topdir/resources/icon.png "$appdir/$LOWERAPP.png"

# Add launcher.
# Note: don't use AppImage's AppRun because
# it will change the working directory.
create_apprun()
{
  cat >"$appdir/AppRun" <<\EOF
#!/usr/bin/env bash
set -e
[ -n "$DEBUG" ] && set -x

APPDIR="$(dirname "$(readlink -e "$0")")"
export LANG=en_US.UTF-8
export PATH="${APPDIR}"/usr/bin/:"${APPDIR}"/usr/sbin/:"${APPDIR}"/usr/games/:"${APPDIR}"/bin/:"${APPDIR}"/sbin/:"${PATH}"
export LD_LIBRARY_PATH="${APPDIR}"/usr/lib/:"${APPDIR}"/usr/lib/i386-linux-gnu/:"${APPDIR}"/usr/lib/x86_64-linux-gnu/:"${APPDIR}"/usr/lib32/:"${APPDIR}"/usr/lib64/:"${APPDIR}"/lib/:"${APPDIR}"/lib/i386-linux-gnu/:"${APPDIR}"/lib/x86_64-linux-gnu/:"${APPDIR}"/lib32/:"${APPDIR}"/lib64/:"${LD_LIBRARY_PATH}"
export PYTHONPATH="${APPDIR}"/usr/share/pyshared/:"${PYTHONPATH}"
EXEC=$(grep -e '^Exec=.*' "${APPDIR}"/*.desktop | head -n 1 | cut -d "=" -f 2 | cut -d " " -f 1)
PROGRAM="${1##*/}"
if [ "x$PROGRAM" != "x" ]; then
  shift
  exec "${PROGRAM}" "$@"
else
  exec "${EXEC}" $@
fi
EOF
  chmod +x "$appdir/AppRun"
}
run create_apprun

# Finalize AppDir.
(
  run . "$cachedir/functions.sh"
  run cd "$appdir"
  # Add desktop integration.
  run get_desktopintegration $LOWERAPP
  # Fix missing system dependencies.
  run copy_deps; run copy_deps; run copy_deps
  run move_lib
  # Move usr/include out of the way to preserve usr/include/python3.5m.
  run mv usr/include usr/include.tmp
  run delete_blacklisted
  run mv usr/include.tmp usr/include
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
run strip_binaries

# Remove empty directories.
remove_emptydirs()
{
  find "$appdir" -type d -empty -print0 | xargs -0 --no-run-if-empty rmdir -vp --ignore-fail-on-non-empty
}
run remove_emptydirs

run . "$cachedir/functions.sh"
run cd "$builddir"
run rm -rf openssl-*
GLIBC_NEEDED=${GLIBC_NEEDED:=$(glibc_needed)}
run set_arch
appimage="$distdir/$APP-$VERSION.glibc${GLIBC_NEEDED}-$ARCH.AppImage"

# Create image with appimagetool
# Note: extract appimagetool so fuse is not needed.
run chmod +x "$cachedir/appimagetool"
run "$cachedir/appimagetool" --appimage-extract
run env VERSION="$VERSION" ./squashfs-root/AppRun --no-appstream --verbose -u 'gh-releases-zsync|nandub|Mitmproxy.AppImage|latest|Mitmproxy-*-$ARCH.AppImage.zsync' "$appdir" "$appimage"

#Useful when running inside docker.
if [ -d /image ]; then
  run cp -p "$distdir/*" /image/
fi
