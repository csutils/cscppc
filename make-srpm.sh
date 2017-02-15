#/bin/bash

# Copyright (C) 2012-2013 Red Hat, Inc.
#
# This file is part of cscppc.
#
# cscppc is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# cscppc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cscppc.  If not, see <http://www.gnu.org/licenses/>.

SELF="$0"

PKG="cscppc"

die() {
    echo "$SELF: error: $1" >&2
    exit 1
}

match() {
    grep "$@" > /dev/null
}

DST="`readlink -f "$PWD"`"

REPO="`git rev-parse --show-toplevel`"
test -d "$REPO" || die "not in a git repo"

NV="`git describe --tags`"
echo "$NV" | match "^$PKG-" || die "release tag not found"

VER="`echo "$NV" | sed "s/^$PKG-//"`"

TIMESTAMP="`git log --pretty="%cd" --date=iso -1 \
    | tr -d ':-' | tr ' ' . | cut -d. -f 1,2`"

VER="`echo "$VER" | sed "s/-.*-/.$TIMESTAMP./"`"

BRANCH="`git rev-parse --abbrev-ref HEAD`"
test -n "$BRANCH" || die "failed to get current branch name"
test master = "${BRANCH}" || VER="${VER}.${BRANCH}"
test -z "`git diff HEAD`" || VER="${VER}.dirty"

NV="${PKG}-${VER}"
printf "%s: preparing a release of \033[1;32m%s\033[0m\n" "$SELF" "$NV"

TMP="`mktemp -d`"
trap "echo --- $SELF: removing $TMP... 2>&1; rm -rf '$TMP'" EXIT
cd "$TMP" >/dev/null || die "mktemp failed"

# clone the repository
git clone "$REPO" "$PKG"                || die "git clone failed"
cd "$PKG"                               || die "git clone failed"

make -j9 distcheck CTEST='ctest -j9'    || die "'make distcheck' has failed"

SRC_TAR="${NV}.tar"
SRC="${SRC_TAR}.xz"
git archive --prefix="$NV/" --format="tar" HEAD -- . > "${TMP}/${SRC_TAR}" \
                                        || die "failed to export sources"
cd "$TMP" >/dev/null                    || die "mktemp failed"
xz -c "$SRC_TAR" > "$SRC"               || die "failed to compress sources"

SPEC="$TMP/$PKG.spec"
cat > "$SPEC" << EOF
Name:       $PKG
Version:    $VER
Release:    1%{?dist}
Summary:    A compiler wrapper that runs cppcheck in background

Group:      Development/Tools
License:    GPLv3+
URL:        https://github.com/kdudka/%{name}
Source0:    https://github.com/kdudka/%{name}/releases/download/%{name}-%{version}/%{name}-%{version}.tar.xz

BuildRequires: asciidoc
BuildRequires: cmake

# The test-suite runs automatically trough valgrind if valgrind is available
# on the system.  By not installing valgrind into mock's chroot, we disable
# this feature for production builds on architectures where valgrind is known
# to be less reliable, in order to avoid unnecessary build failures (see RHBZ
# #810992, #816175, and #886891).  Nevertheless developers are free to install
# valgrind manually to improve test coverage on any architecture.
%ifarch %{ix86} x86_64
BuildRequires: valgrind
%endif

# csmock copies the resulting cscppc binary into mock chroot, which may contain
# an older (e.g. RHEL-5) version of glibc, and it would not dynamically link
# against the old version of glibc if it was built against a newer one.
# Therefor we link glibc statically.
%if (0%{?fedora} >= 12 || 0%{?rhel} >= 6)
BuildRequires: glibc-static
%endif

# the --include option was introduced in 1.58
Requires: cppcheck >= 1.58

%description
This package contains the cscppc compiler wrapper that runs cppcheck in
background fully transparently.

%package -n csclng
Summary: A compiler wrapper that runs Clang in background
Requires: clang
Conflicts: csmock-plugin-clang < 1.5.0

%description -n csclng
This package contains the csclng compiler wrapper that runs the Clang analyzer
in background fully transparently.

%prep
%setup -q

%build
mkdir cscppc_build
cd cscppc_build
export CFLAGS="\$RPM_OPT_FLAGS"' -DPATH_TO_CSCPPC=\\"%{_libdir}/cscppc\\" -DPATH_TO_CSCLNG=\\"%{_libdir}/csclng\\"'
export LDFLAGS="\$RPM_OPT_FLAGS -static -pthread"
%cmake ..
make %{?_smp_mflags} VERBOSE=yes

%check
cd cscppc_build
ctest %{?_smp_mflags} --output-on-failure

%install
cd cscppc_build
make install DESTDIR="\$RPM_BUILD_ROOT"

install -m0755 -d "\$RPM_BUILD_ROOT%{_libdir}"{,/cscppc,/csclng}

for i in cc gcc %{_arch}-redhat-linux-gcc
do
    ln -s ../../bin/cscppc "\$RPM_BUILD_ROOT%{_libdir}/cscppc/\$i"
    ln -s ../../bin/csclng "\$RPM_BUILD_ROOT%{_libdir}/csclng/\$i"
done

for i in c++ g++ %{_arch}-redhat-linux-c++ %{_arch}-redhat-linux-g++
do
    ln -s ../../bin/cscppc   "\$RPM_BUILD_ROOT%{_libdir}/cscppc/\$i"
    ln -s ../../bin/csclng++ "\$RPM_BUILD_ROOT%{_libdir}/csclng/\$i"
done

%files
%{_bindir}/cscppc
%{_datadir}/cscppc
%{_datadir}/cscppc/default.supp
%{_libdir}/cscppc
%{_mandir}/man1/%{name}.1*
%doc COPYING README

%files -n csclng
%{_bindir}/csclng
%{_bindir}/csclng++
%{_libdir}/csclng
%{_mandir}/man1/csclng.1*
%doc COPYING README
EOF

rpmbuild -bs "$SPEC"                            \
    --define "_sourcedir $TMP"                  \
    --define "_specdir $TMP"                    \
    --define "_srcrpmdir $DST"
