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

	%post
	/sbin/chkconfig --add syncthing

	%preun
	if [ \$1 = 0 ]; then # package is being erased, not upgraded
	    /sbin/service syncthing stop > /dev/null 2>&1
	    /sbin/chkconfig --del syncthing
	fi

	%files
	%defattr(-,root,root,-)
	%config(noreplace) /etc/init.d/*
	%config(noreplace) /etc/sysconfig/*
	%{_bindir}/*

	%changelog
	* Tue Dec 22 2015 Marc Argent <marc.argent@toumaz.com> $VERSION-$RELEASE
	- First Build
EOF
}

create_init_script()
{
  cat <<- 'EOF' > $DIR/syncthing
	#!/bin/bash
	#
	# syncthing
	#
	# chkconfig: 345 70 30
	# description: Syncthing synchronises files between servers

	PROG="/usr/bin/syncthing"

	# Source config
	if [ -f /etc/sysconfig/syncthing ] ; then
	  . /etc/sysconfig/syncthing
	fi

	start() {
	  check_users
	  for stuser in $SYNCTHING_USERS; do
	    pgrep -U $stuser -f $PROG 2>&1>/dev/null
	    if [ $? -eq 0 ] ; then
	      echo "Syncthing already running for ${stuser}"
	    else
	      echo "Starting syncthing for $stuser"
	      su -c "${PROG} 2>&1>/dev/null &" $stuser
	    fi
	  done
	}

	stop() {
	  check_users
	  for stuser in $SYNCTHING_USERS; do
	    echo "Stopping syncthing for ${stuser}"
	    pkill -U $stuser -f /usr/bin/syncthing
	  done
	}

	status() {
	  check_users
	  for stuser in $SYNCTHING_USERS; do
	    pgrep -U $stuser -f $PROG 2>&1>/dev/null
	    if [ $? -eq 0 ] ; then
	      echo "Syncthing for $stuser: running."
	    else
	      echo "Syncthing for $stuser: not running."
	    fi
	  done
	}

	check_users() {
	  if [ -z "$SYNCTHING_USERS" ] ; then
	    echo "No users specified, add them in /etc/sysconfig/syncthing"
	    exit
	  fi
	}

	case "$1" in
	  start) start
	    ;;
	  stop) stop
	    ;;
	  restart|reload|force-reload) stop && start
	    ;;
	  status) status
	    ;;
	  *) echo "Usage: /etc/init.d/syncthing {start|stop|reload|force-reload|restart|status}"
	     exit 1
	   ;;
	esac

	exit 0
EOF
}

create_sysconfig_script()
{
  cat <<- 'EOF' > $DIR/syncthing-sysconfig
	# Options for syncthing
	# Specify a space separated list of users to run syncthing
	SYNCTHING_USERS=""
EOF
}

make_tarball()
{
  cd $DIR

  if [ ! -f syncthing-linux-amd64-$VERSION.tar.gz ]
  then
    wget http://archive.syncthing.net/$VERSION/syncthing-linux-amd64-$VERSION.tar.gz
  fi

  tar xzvf syncthing-linux-amd64-$VERSION.tar.gz
  mkdir -p syncthing-$VERSION/usr/bin
  mkdir -p syncthing-$VERSION/etc/init.d
  mkdir -p syncthing-$VERSION/etc/sysconfig

  create_init_script
  create_sysconfig_script

  install -m 755 syncthing-linux-amd64-$VERSION/syncthing syncthing-$VERSION/usr/bin
  install -m 755 syncthing syncthing-$VERSION/etc/init.d
  install -m 644 syncthing-sysconfig syncthing-$VERSION/etc/sysconfig/syncthing
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
  rm $DIR/syncthing
  rm $DIR/syncthing-sysconfig
  rm -rf $DIR/syncthing-linux-amd64-$VERSION*
  rm -rf $DIR/syncthing-$VERSION
}

make_rpm_environment
make_tarball
copy_tarball
build_rpm
cleanup
