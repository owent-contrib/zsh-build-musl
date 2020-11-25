ZSH_VERSION=5.8
MUSL_VERSION=1.2.1
GDBM_VERSION=1.18.1
READLINE_VERSION=8.0
NCURSES_VERSION=6.2
PCRE_VERSION=8.44
ZLIB_VERSION=1.2.11
LIBCAP_VERSION=2.45

if [[ -z "$ZSH_TOOLCHAIN_PREFIX" ]]; then
    ZSH_TOOLCHAIN_PREFIX=$PWD/$ZSH_VERSION-toolchain
fi
if [[ -z "$ZSH_PREFIX" ]]; then
    ZSH_PREFIX=/opt/zsh/zsh-$ZSH_VERSION
fi

# echo "TOKEN" | docker login ;
# docker pull docker.io/muslcc/x86_64:x86_64-linux-musl ;
# apk add curl ;
# https://musl.cc/x86_64-linux-musl-cross.tgz
# https://musl.cc/x86_64-linux-musl-native.tgz

if [[ ! -e "$HOME/x86_64-linux-musl-native" ]]; then
    curl -kL https://musl.cc/x86_64-linux-musl-native.tgz -o x86_64-linux-musl-native.tgz;
    tar -axvf x86_64-linux-musl-native.tgz;
    if [[ "$PWD" != "$HOME" ]]; then
        mv x86_64-linux-musl-native "$HOME/x86_64-linux-musl-native";
    fi
fi
TOOLCHAIN_DIR="$HOME/x86_64-linux-musl-native";

BUILD_THREAD_OPT=6 ;
BUILD_CPU_NUMBER=$(cat /proc/cpuinfo | grep -c "^processor[[:space:]]*:[[:space:]]*[0-9]*") ;
BUILD_THREAD_OPT=$BUILD_CPU_NUMBER ;
if [[ $BUILD_THREAD_OPT -gt 6 ]]; then
    BUILD_THREAD_OPT=$(($BUILD_CPU_NUMBER-1)) ;
fi
BUILD_THREAD_OPT="-j$BUILD_THREAD_OPT" ;


if [[ -z "$CFLAGS" ]]; then
    export CFLAGS="-fPIC -I$ZSH_TOOLCHAIN_PREFIX/include -I$ZSH_PREFIX/include";
else
    export CFLAGS="$CFLAGS -fPIC -I$ZSH_TOOLCHAIN_PREFIX/include -I$ZSH_PREFIX/include";
fi
if [[ -z "$CXXFLAGS" ]]; then
    export CXXFLAGS="-fPIC -I$ZSH_TOOLCHAIN_PREFIX/include -I$ZSH_PREFIX/include";
else
    export CXXFLAGS="$CXXFLAGS -fPIC -I$ZSH_TOOLCHAIN_PREFIX/include -I$ZSH_PREFIX/include";
fi
if [[ -z "$LDFLAGS" ]]; then
    export LDFLAGS="-L$ZSH_TOOLCHAIN_PREFIX/lib64 -L$ZSH_TOOLCHAIN_PREFIX/lib -L$ZSH_PREFIX/lib -static";
else
    export LDFLAGS="$LDFLAGS -L$ZSH_TOOLCHAIN_PREFIX/lib64 -L$ZSH_TOOLCHAIN_PREFIX/lib -L$ZSH_PREFIX/lib -static";
fi

NATIVE_CC="$(readlink -f $(which gcc))"
NATIVE_CXX="$(readlink -f $(which g++))"

export CC=$TOOLCHAIN_DIR/bin/x86_64-linux-musl-gcc ;
export CXX=$TOOLCHAIN_DIR/bin/x86_64-linux-musl-g++ ;
export LD=$TOOLCHAIN_DIR/bin/ld ;
export PATH=$TOOLCHAIN_DIR/bin:$ZSH_PREFIX/bin:$PATH ;
if [[ "x$PKG_CONFIG_PATH" == "x" ]]; then
    export PKG_CONFIG_PATH="$ZSH_TOOLCHAIN_PREFIX/lib/pkgconfig"
else
    export PKG_CONFIG_PATH="$ZSH_TOOLCHAIN_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
fi

curl -kL http://zlib.net/zlib-$ZLIB_VERSION.tar.gz -o zlib-$ZLIB_VERSION.tar.gz ;
tar -axvf zlib-$ZLIB_VERSION.tar.gz ;
cd zlib-$ZLIB_VERSION ;
./configure --prefix=$ZSH_TOOLCHAIN_PREFIX "--eprefix=$ZSH_PREFIX" --static ;
make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;

curl -kL "https://invisible-mirror.net/archives/ncurses/ncurses-$NCURSES_VERSION.tar.gz" -o ncurses-$NCURSES_VERSION.tar.gz ;
tar -axvf ncurses-$NCURSES_VERSION.tar.gz ;
cd ncurses-$NCURSES_VERSION ;
make clean || true;
./configure "--prefix=$ZSH_TOOLCHAIN_PREFIX" "--exec-prefix=$ZSH_PREFIX"            \
    "--with-pkg-config-libdir=$ZSH_TOOLCHAIN_PREFIX/lib/pkgconfig"                  \
    --with-normal --without-debug --without-ada --with-termlib --enable-termcap     \
    --enable-pc-files --with-cxx-binding                                            \
    --enable-ext-colors --enable-ext-mouse --enable-bsdpad --enable-opaque-curses   \
    --with-terminfo-dirs=/etc/terminfo:/usr/share/terminfo:/lib/terminfo            \
    --with-termpath=/etc/termcap:/usr/share/misc/termcap ;

make $BUILD_THREAD_OPT || make ;
make install ;

make clean ;
./configure "--prefix=$ZSH_TOOLCHAIN_PREFIX" "--exec-prefix=$ZSH_PREFIX"            \
    "--with-pkg-config-libdir=$ZSH_TOOLCHAIN_PREFIX/lib/pkgconfig"                  \
    --with-normal --without-debug --without-ada --with-termlib --enable-termcap     \
    --enable-widec --enable-pc-files --with-cxx-binding                             \
    --enable-ext-colors --enable-ext-mouse --enable-bsdpad --enable-opaque-curses   \
    --with-terminfo-dirs=/etc/terminfo:/usr/share/terminfo:/lib/terminfo            \
    --with-termpath=/etc/termcap:/usr/share/misc/termcap ;

make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;
if [[ -z "$LIBS" ]]; then
    export LIBS="-ltinfow";
else
    export LIBS="$LIBS -ltinfow";
fi


curl -kL https://ftp.gnu.org/gnu/readline/readline-$READLINE_VERSION.tar.gz -o readline-$READLINE_VERSION.tar.gz ;
tar -axvf readline-$READLINE_VERSION.tar.gz ;
cd readline-$READLINE_VERSION ;
./configure "--prefix=$ZSH_TOOLCHAIN_PREFIX" "--exec-prefix=$ZSH_PREFIX" --enable-static=yes --enable-shared=no --enable-multibyte --with-curses ;
make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;

curl -kL https://ftp.pcre.org/pub/pcre/pcre-$PCRE_VERSION.tar.gz -o pcre-$PCRE_VERSION.tar.gz;
tar -axvf pcre-$PCRE_VERSION.tar.gz ;
cd pcre-$PCRE_VERSION ;
./configure "--prefix=$ZSH_TOOLCHAIN_PREFIX" "--exec-prefix=$ZSH_PREFIX" --with-pic=yes --enable-shared=no --enable-static=yes  \
    --enable-utf --enable-unicode-properties --enable-pcre16 --enable-pcre32 --enable-jit                                       \
    --enable-pcregrep-libz --enable-pcretest-libreadline
make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;

# libcap require kernel headers and built with static linking
curl -kL https://mirrors.edge.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-$LIBCAP_VERSION.tar.xz -o libcap-$LIBCAP_VERSION.tar.xz ;
tar -axvf libcap-$LIBCAP_VERSION.tar.xz ;
cd libcap-$LIBCAP_VERSION ;
# CC=$ZSH_TOOLCHAIN_PREFIX/bin/musl-gcc
# LD_LIBRARY_PATH=$TOOLCHAIN_DIR/lib:$LD_LIBRARY_PATH
make RAISE_SETFCAP='no' SHARED='no' CC=$CC BUILD_CC="$NATIVE_CC" LD=$LD CROSS_COMPILE=x86_64-linux-musl-gcc- prefix=$ZSH_TOOLCHAIN_PREFIX install ;
cd .. ;

curl -kL https://ftp.gnu.org/gnu/gdbm/gdbm-$GDBM_VERSION.tar.gz -o gdbm-$GDBM_VERSION.tar.gz ;
tar -axvf gdbm-$GDBM_VERSION.tar.gz ;
cd gdbm-$GDBM_VERSION;
env CFLAGS="$CFLAGS -fcommon" ./configure "--prefix=$ZSH_PREFIX" --with-pic=yes --enable-shared=no --enable-static=yes ;
make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;

curl -kL https://nchc.dl.sourceforge.net/project/zsh/zsh/$ZSH_VERSION/zsh-$ZSH_VERSION.tar.xz -o zsh-$ZSH_VERSION.tar.xz ;
tar -axvf zsh-$ZSH_VERSION.tar.xz ;
cd zsh-$ZSH_VERSION ;
./configure "--prefix=$ZSH_PREFIX"          \
        --docdir=/usr/share/doc/zsh         \
        --htmldir=/usr/share/doc/zsh/html   \
        --enable-etcdir=/etc/zsh            \
        --enable-zshenv=/etc/zsh/zshenv     \
        --enable-zlogin=/etc/zsh/zlogin     \
        --enable-zlogout=/etc/zsh/zlogout   \
        --enable-zprofile=/etc/zsh/zprofile \
        --enable-zshrc=/etc/zsh/zshrc       \
        --enable-maildir-support            \
        --with-term-lib='ncursesw'          \
        --enable-multibyte                  \
        --enable-zsh-secure-free            \
        --enable-function-subdirs                   \
        --enable-pcre --enable-cap                  \
        --enable-unicode9 --enable-libc-musl        \
        --with-tcsetpgrp ;
make $BUILD_THREAD_OPT || make ;
make install ;
cd .. ;
