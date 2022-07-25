#!/bin/bash

# Copyright (C) 2012-2022 Red Hat, Inc.
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

DST="$(readlink -f "$PWD")"

REPO="$(git rev-parse --show-toplevel)"
test -d "$REPO" || die "not in a git repo"

NV="$(git describe --tags)"
echo "$NV" | match "^$PKG-" || die "release tag not found"

VER="$(echo "$NV" | sed "s/^$PKG-//")"

TIMESTAMP="$(git log --pretty="%cd" --date=iso -1 \
    | tr -d ':-' | tr ' ' . | cut -d. -f 1,2)"

VER="$(echo "$VER" | sed "s/-.*-/.$TIMESTAMP./")"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
test -n "$BRANCH" || die "failed to get current branch name"
test "main" = "${BRANCH}" || VER="${VER}.${BRANCH//[\/-]/_}"
test -z "$(git diff HEAD)" || VER="${VER}.dirty"

NV="${PKG}-${VER}"
printf "%s: preparing a release of \033[1;32m%s\033[0m\n" "$SELF" "$NV"

SPEC="$PKG.spec"
TMP="$(mktemp -d)"
trap "rm -rf '$TMP'" EXIT
pushd "$TMP" >/dev/null || die "mktemp failed"

# clone the repository
git clone --recurse-submodules "$REPO" "$PKG" \
                                        || die "git clone failed"
pushd "$PKG"                            || die "git clone failed"

if [[ "$1" != "--generate-sources" ]]; then
    make distcheck                          || die "'make distcheck' has failed"
fi

SRC_TAR="${NV}.tar"
SRC="${SRC_TAR}.xz"
git archive --prefix="$NV/" --format="tar" HEAD -- . > "${TMP}/${SRC_TAR}" \
                                        || die "failed to export sources"
(cd cswrap && git archive --prefix="$NV/cswrap/" --format="tar" HEAD -- \
    src/cswrap-util.{c,h} > ../cswrap-util.tar) \
                                        || die "failed to export submodule"
tar -Af "${TMP}/${SRC_TAR}" cswrap-util.tar \
                                        || die "failed to concatenate TAR"
popd >/dev/null                         || die "mktemp failed"
xz -c "${TMP}/${SRC_TAR}" > "${TMP}/${SRC}" \
                                        || die "failed to compress sources"

if [[ "$1" == "--generate-sources" ]]; then
    popd > /dev/null
    mv "${TMP}/${SRC}" .
else
    SPEC="$TMP/$SPEC"
fi

cat > "$SPEC" << EOF
# Disable in source builds on EPEL <9
%undefine __cmake_in_source_build
%undefine __cmake3_in_source_build

Name:       $PKG
Version:    $VER
Release:    1%{?dist}
Summary:    A compiler wrapper that runs Cppcheck in background

License:    GPLv3+
URL:        https://github.com/csutils/%{name}
Source0:    https://github.com/csutils/%{name}/releases/download/%{name}-%{version}/%{name}-%{version}.tar.xz

BuildRequires: asciidoc
BuildRequires: cmake3
BuildRequires: gcc

# csmock copies the resulting cscppc binary into mock chroot, which may contain
# an older (e.g. RHEL-7) version of glibc, and it would not dynamically link
# against the old version of glibc if it was built against a newer one.
# Therefore, we link glibc statically.
BuildRequires: glibc-static

# The test-suite runs automatically trough valgrind if valgrind is available
# on the system.  By not installing valgrind into mock's chroot, we disable
# this feature for production builds on architectures where valgrind is known
# to be less reliable, in order to avoid unnecessary build failures (see RHBZ
# #810992, #816175, and #886891).  Nevertheless developers are free to install
# valgrind manually to improve test coverage on any architecture.
%ifarch %{ix86} x86_64
BuildRequires: valgrind
%endif

# the {cwe} field in --template option is supported since cppcheck-1.85
Requires: cppcheck >= 1.85

# older versions of csdiff do not read CWE numbers from Cppcheck output
Conflicts: csdiff < 1.8.0

%description
This package contains the cscppc compiler wrapper that runs Cppcheck in
background fully transparently.

%package -n csclng
Summary: A compiler wrapper that runs Clang in background
Requires: clang
Conflicts: csmock-plugin-clang < 1.5.0

%description -n csclng
This package contains the csclng compiler wrapper that runs the Clang analyzer
in background fully transparently.

%package -n csgcca
Summary: A compiler wrapper that runs 'gcc -fanalyzer' in background

%description -n csgcca
This package contains the csgcca compiler wrapper that runs 'gcc -fanalyzer'
in background fully transparently.

%package -n csmatch
Summary: A compiler wrapper that runs Smatch in background
Requires: clang

%description -n csmatch
This package contains the csmatch compiler wrapper that runs the Smatch analyzer
in background fully transparently.

%prep
%autosetup

%build
%cmake3                                       \\
    -DPATH_TO_CSCPPC=\"%{_libdir}/cscppc\"    \\
    -DPATH_TO_CSCLNG=\"%{_libdir}/csclng\"    \\
    -DPATH_TO_CSGCCA=\"%{_libdir}/csgcca\"    \\
    -DPATH_TO_CSMATCH=\"%{_libdir}/csmatch\"  \\
    -DSTATIC_LINKING=ON
%cmake3_build

%check
%ctest3

%install
%cmake3_install

install -m0755 -d "%{buildroot}%{_libdir}"{,/cs{cppc,clng,gcca,match}}

for i in cc gcc %{_arch}-redhat-linux-gcc
do
    ln -s ../../bin/cscppc  "%{buildroot}%{_libdir}/cscppc/\$i"
    ln -s ../../bin/csclng  "%{buildroot}%{_libdir}/csclng/\$i"
    ln -s ../../bin/csgcca  "%{buildroot}%{_libdir}/csgcca/\$i"
    ln -s ../../bin/csmatch "%{buildroot}%{_libdir}/csmatch/\$i"
done

for i in c++ g++ %{_arch}-redhat-linux-c++ %{_arch}-redhat-linux-g++
do
    ln -s ../../bin/cscppc   "%{buildroot}%{_libdir}/cscppc/\$i"
    ln -s ../../bin/csclng++ "%{buildroot}%{_libdir}/csclng/\$i"
done

%files
%{_bindir}/cscppc
%{_datadir}/cscppc
%{_libdir}/cscppc
%{_mandir}/man1/%{name}.1*
%doc COPYING README

%files -n csclng
%{_bindir}/csclng
%{_bindir}/csclng++
%{_libdir}/csclng
%{_mandir}/man1/csclng.1*
%doc COPYING

%files -n csgcca
%{_bindir}/csgcca
%{_libdir}/csgcca
%{_mandir}/man1/csgcca.1*
%doc COPYING

%files -n csmatch
%{_bindir}/csmatch
%{_libdir}/csmatch
%{_mandir}/man1/csmatch.1*
%doc COPYING
EOF

if [[ "$1" != "--generate-sources" ]]; then
    rpmbuild -bs "$SPEC"                            \
        --define "_sourcedir $TMP"                  \
        --define "_specdir $TMP"                    \
        --define "_srcrpmdir $DST"
fi
