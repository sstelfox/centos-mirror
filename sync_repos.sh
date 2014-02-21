#!/bin/bash

rsync --progress  -h -av --delete --delete-excluded --exclude "SRPMS" \
  --exclude="ppc64" --exclude "local*" --exclude "isos" --exclude "i386" \
  --exclude="SCL" --exclude="xen4" rsync://mirrors.kernel.org/centos/6.5/ \
  ~/tmp-centos-mirror/repo/centos/6.5/

rsync --progress  -h -av --delete --delete-excluded --exclude "SRPMS" \
  --exclude="ppc64" --exclude "local*" --exclude "isos" --exclude "i386" \
  rsync://mirror.pnl.gov/epel/6/ ~/tmp-centos-mirror/repo/epel/6/
