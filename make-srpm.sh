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
test -d "$TMP" || die "mktemp failed"

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
URL:        https://git.fedorahosted.org/cgit/cscppc.git
Source0:    https://git.fedorahosted.org/cgit/cscppc.git/snapshot/$SRC

BuildRequires: asciidoc

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

%description -n csclng
This package contains the csclng compiler wrapper that runs the Clang analyzer
in background fully transparently.

%prep
%setup -q

%build
make %{?_smp_mflags} \\
    CFLAGS="\$RPM_OPT_FLAGS -DPATH_TO_CSCPPC='\\"%{_libdir}/cscppc\\"' -DPATH_TO_CSCLNG='\\"%{_libdir}/csclng\\"'" \\
    LDFLAGS="\$RPM_OPT_FLAGS -static -pthread"

%install
install -m0755 -d \\
    "\$RPM_BUILD_ROOT%{_bindir}"                \\
    "\$RPM_BUILD_ROOT%{_datadir}"               \\
    "\$RPM_BUILD_ROOT%{_datadir}/cscppc"        \\
    "\$RPM_BUILD_ROOT%{_libdir}"                \\
    "\$RPM_BUILD_ROOT%{_libdir}/cscppc"         \\
    "\$RPM_BUILD_ROOT%{_libdir}/csclng"         \\
    "\$RPM_BUILD_ROOT%{_mandir}/man1"

install -p -m0755 %{name} csclng "\$RPM_BUILD_ROOT%{_bindir}"
install -p -m0644 %{name}.1 csclng.1 "\$RPM_BUILD_ROOT%{_mandir}/man1"
install -p -m0644 default.supp "\$RPM_BUILD_ROOT%{_datadir}/cscppc"

for i in c++ cc g++ gcc \\
    %{_arch}-redhat-linux-c++ \\
    %{_arch}-redhat-linux-g++ \\
    %{_arch}-redhat-linux-gcc
do
    ln -s ../../bin/cscppc "\$RPM_BUILD_ROOT%{_libdir}/cscppc/\$i"
    ln -s ../../bin/csclng "\$RPM_BUILD_ROOT%{_libdir}/csclng/\$i"
done

%files
%{_bindir}/cscppc
%{_datadir}/cscppc
%{_libdir}/cscppc
%{_mandir}/man1/%{name}.1*
%doc COPYING README

%files -n csclng
%{_bindir}/csclng
%{_libdir}/csclng
%{_mandir}/man1/csclng.1*
%doc COPYING README
EOF

rpmbuild -bs "$SPEC"                            \
    --define "_sourcedir $TMP"                  \
    --define "_specdir $TMP"                    \
    --define "_srcrpmdir $DST"
