#!/bin/bash

VERSION="v0.12.9"
RELEASE="1"
HOMEPATH="/export/home/syncthing"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

make_rpm_environment()
{
  if [ -d $DIR/rpmbuild ]
  then
    rm -rf $DIR/rpmbuild
  fi

  mkdir -p $DIR/rpmbuild/{RPMS,SRPMS,BUILD,SOURCES,SPECS,tmp}
  cat <<- EOF > rpmbuild/SPECS/syncthing.spec
	%define	__spec_install_post %{nil}
	%define	debug_package %{nil}
	%define	__os_install_post %{_dbpath}/brp-compress

	Summary: Syncthing replaces proprietary sync and cloud services with something open, trustworthy and decentralized
	Name: syncthing
	Version: $VERSION
	Release: $RELEASE
	License: MPLv2
	Group: System Environment/Daemons
	Requires: httpd
	SOURCE0 : %{name}-%{version}.tar.gz
	URL: http://syncthing.net
	
	BuildRoot: $DIR/rpmbuild/tmp/%{name}-%{version}-%{release}-root

	%description
	%{summary}

	%prep
	%setup -q

	%build
	# Empty section

	%install
	rm -rf %{buildroot}
	mkdir -p %{buildroot}

	# in builddir
	cp -a * %{buildroot}

	%files
	%defattr(-,root,root,-)
	%config(noreplace) /usr/lib/systemd/system/*
	%{_bindir}/*

	%changelog
	* Tue Dec 22 2015 Marc Argent <marc.argent@toumaz.com> $VERSION-$RELEASE
	- First Build
EOF
}

create_systemd_script()
{
  cat <<- EOF > $DIR/syncthing\@.service
	[Unit]
	Description=Syncthing - Open Source Continuous File Synchronization for %I
	Documentation=http://docs.syncthing.net/
	After=network.target
	Wants=syncthing-inotify@.service

	[Service]
	User=%I
	Environment=STNORESTART=yes
	ExecStart=/usr/bin/syncthing -no-browser -logflags=0 -home=$HOMEPATH
	Restart=on-failure
	SuccessExitStatus=2 3 4
	RestartForceExitStatus=3 4

	[Install]
	WantedBy=multi-user.target
EOF
}

make_tarball()
{
  cd $DIR

  if [ ! -f syncthing-linux-amd64-$VERSION.tar.gz ]
  then
    wget https://github.com/syncthing/syncthing/releases/download/$VERSION/syncthing-linux-amd64-$VERSION.tar.gz
  fi

  tar xzvf syncthing-linux-amd64-$VERSION.tar.gz
  mkdir -p syncthing-$VERSION/usr/bin
  mkdir -p syncthing-$VERSION/usr/lib/systemd/system

  create_systemd_script

  install -m 755 syncthing-linux-amd64-$VERSION/syncthing syncthing-$VERSION/usr/bin
  install -m 644 syncthing\@.service syncthing-$VERSION/usr/lib/systemd/system
  tar zcvf syncthing-$VERSION.tar.gz syncthing-$VERSION/
}

copy_tarball()
{
  cp $DIR/syncthing-$VERSION.tar.gz $DIR/rpmbuild/SOURCES
}

build_rpm()
{
  cp $DIR/syncthing-$VERSION.tar.gz $DIR/rpmbuild/SOURCES
  cd $DIR/rpmbuild
  rpmbuild --define "_topdir $DIR/rpmbuild" -ba SPECS/syncthing.spec
  cp $DIR/rpmbuild/RPMS/x86_64/syncthing-$VERSION-$RELEASE.x86_64.rpm $DIR
}

cleanup()
{
  rm -rf $DIR/rpmbuild
  rm $DIR/syncthing-$VERSION.tar.gz
  rm $DIR/syncthing\@.service
  rm -rf $DIR/syncthing-linux-amd64-$VERSION*
  rm -rf $DIR/syncthing-$VERSION
}

make_rpm_environment
make_tarball
copy_tarball
build_rpm
cleanup
