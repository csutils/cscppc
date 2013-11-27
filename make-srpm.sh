#/bin/bash

# Copyright (C) 2012-2013 Red Hat, Inc.
#
# This file is part of cppcheck-gcc.
#
# cppcheck-gcc is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# cppcheck-gcc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cppcheck-gcc.  If not, see <http://www.gnu.org/licenses/>.

SELF="$0"

PKG="cppcheck-gcc"

die(){
    echo "$SELF: error: $1" >&2
    exit 1
}

DST="`readlink -f "$PWD"`"

REPO="`git rev-parse --show-toplevel`" \
    || die "not in a git repo"

printf "%s: considering release of %s using %s...\n" \
    "$SELF" "$PKG" "$REPO"

branch="`git status | head -1 | sed 's/^#.* //'`" \
    || die "unable to read git branch"

test xmaster = "x$branch" \
    || die "not in master branch"

test -z "`git diff HEAD`" \
    || die "HEAD dirty"

test -z "`git diff origin/master`" \
    || die "not synced with origin/master"

VER="0.`git log --pretty="%cd_%h" --date=short -1 | tr -d -`" \
    || die "git log failed"

NV="${PKG}-$VER"
SRC="${PKG}.tar.xz"

TMP="`mktemp -d`"
trap "echo --- $SELF: removing $TMP... 2>&1; rm -rf '$TMP'" EXIT
test -d "$TMP" || die "mktemp failed"
SPEC="$TMP/$PKG.spec"
cat > "$SPEC" << EOF
Name:       $PKG
Version:    $VER
Release:    1%{?dist}
Summary:    A GCC wrapper that runs cppcheck.

Group:      Development/Tools
License:    GPLv3+
URL:        https://engineering.redhat.com/trac/CoverityScan
Source0:    http://git.engineering.redhat.com/?p=users/kdudka/coverity-scan.git;a=blob_plain;f=cppcheck-gcc/cppcheck-gcc
Source1:    http://git.engineering.redhat.com/?p=users/kdudka/coverity-scan.git;a=blob_plain;f=cppcheck-gcc/default.supp

BuildRoot:  %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

# the --include option was introduced in 1.58
Requires: cppcheck >= 1.58

# FIXME
ExclusiveArch: x86_64

%description
This package contains the cppcheck-gcc shell script to hook cppcheck on gcc
during the build fully transparently.

%build

%clean
rm -rf "\$RPM_BUILD_ROOT"

%install
rm -rf "\$RPM_BUILD_ROOT"

install -m0755 -d \\
    "\$RPM_BUILD_ROOT%{_bindir}"                \\
    "\$RPM_BUILD_ROOT%{_datadir}"               \\
    "\$RPM_BUILD_ROOT%{_datadir}/cppcheck-gcc"  \\
    "\$RPM_BUILD_ROOT%{_libdir}"                \\
    "\$RPM_BUILD_ROOT%{_libdir}/cppcheck-gcc"

install -m0755 %{SOURCE0} "\$RPM_BUILD_ROOT%{_bindir}"
install -m0644 %{SOURCE1} "\$RPM_BUILD_ROOT%{_datadir}/cppcheck-gcc"

for i in c++ cc g++ gcc \\
    %{_arch}-redhat-linux-c++ \\
    %{_arch}-redhat-linux-g++ \\
    %{_arch}-redhat-linux-gcc
do
    ln -s ../../bin/cppcheck-gcc "\$RPM_BUILD_ROOT%{_libdir}/cppcheck-gcc/\$i"
done

%files
%defattr(-,root,root,-)
%{_bindir}/cppcheck-gcc
%{_datadir}/cppcheck-gcc
%{_libdir}/cppcheck-gcc
EOF

rpmbuild -bs "$SPEC"                            \
    --define "_sourcedir ."                     \
    --define "_specdir ."                       \
    --define "_srcrpmdir $DST"                  \
    --define "_source_filedigest_algorithm md5" \
    --define "_binary_filedigest_algorithm md5"
