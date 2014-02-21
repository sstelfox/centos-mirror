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

