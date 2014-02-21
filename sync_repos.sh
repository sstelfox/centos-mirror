#!/bin/bash

mkdir -p ./repo/centos/6.5/
rsync --progress -h -av --delete --delete-excluded --exclude "SRPMS" \
  --exclude="ppc64" --exclude "local*" --exclude "isos" --exclude "i386" \
  --exclude="SCL" --exclude="xen4" rsync://mirrors.kernel.org/centos/6.5/ \
  ./repo/centos/6.5/

mkdir -p ./repo/epel/6/
rsync --progress -h -av --delete --delete-excluded --exclude "SRPMS" \
  --exclude="ppc64" --exclude "local*" --exclude "isos" --exclude "i386" \
  rsync://mirror.pnl.gov/epel/6/ ./repo/epel/6/

mkdir -p ./repo/puppet/
rsync --progress -h -avxH --exclude "apt*" --exclude "i386" --exclude "SRPMS" \
  --exclude "fedora" --exclude "5" --exclude "devel" --exclude 'yumclear' \
  --prune-empty-dirs --delete --delete-excluded \
  rsync://yum.puppetlabs.com/packages/ ./repo/puppet/

mkdir -p ./repo/postgresql/9.3/
rsync --progress -h -av --delete --delete-excluded --exclude "SRPMS" \
  --exclude="ppc64" --exclude "local*" --exclude "isos" --exclude "*i386" \
  --exclude="fedora*" --exclude="rhel-5*" \
  rsync://yum.postgresql.org/pgrpm-93/ ./repo/postgresql/9.3/

if [ ! -f RPM-GPG-KEY-PGDG-93 ]; then
  wget http://yum.postgresql.org/RPM-GPG-KEY-PGDG-93 -O RPM-GPG-KEY-PGDG-93 &> /dev/null
fi

if [ ! -f RPM-GPG-KEY-elrepo.org ]; then
  wget https://www.elrepo.org/RPM-GPG-KEY-elrepo.org -O RPM-GPG-KEY-elrepo.org &> /dev/null
fi

if [ ! -f RPM-GPG-KEY-puppetlabs ]; then
  wget https://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs -O RPM-GPG-KEY-puppetlabs &> /dev/null
fi

