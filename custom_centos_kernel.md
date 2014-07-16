
As root:

```
yum groupinstall "Development Tools" -y
yum install ncurses-devel hmaccalc zlib-devel binutils-devel elfutils-libelf-devel rpm-build redhat-rpm-config asciidoc hmaccalc perl-ExtUtils-Embed xmlto audit-libs-devel binutils-devel elfutils-devel elfutils-libelf-devel newt-devel python-devel zlib-devel -y
```

As user:

```
mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros
rpm -i http://vault.centos.org/6.5/updates/Source/SPackages/kernel-2.6.32-431.20.3.el6.src.rpm 2>&1 | grep -v mock
```


fuck this


```
mkdir ~/tmp
cd ~/tmp
wget https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.15.1.tar.xz
tar -xJf linux-3.15.1.tar.xz
```

