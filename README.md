# Auto CentOS Mirror

I use this repository when I want to setup and test various server
configurations whlie travelling.

The `sync_repos.sh` script was pulled straight from my production repository
mirror though I've added a few excludes to keep it as small as necessary
(mostly cutting out architectures I don't use and source RPMs).

The kickstart file is also from my production setup with some post-install
steps removed and some custom ones put in place for things such as escrow'd
keys. This will also install MY public SSH key, which I recommend you remove.
You never know when I'll be in the seat next to you ;)

## Requirements

I use this on a Fedora laptop, with KVM & libvirt already setup. My development
network is configured to be 10.64.89.0/24 with my laptop being the gateway on
.1. You'll need at least 29Gbs of space free just for the repository (you'll
need additional space for your virtual machines).

I use Ruby with the `thin` gem installed as my one off webserver hosting the
repository files, as well as a dynamic kickstart file.

If you're using a different network for your VM's you'll need to change the
kickstart template located near the bottom of the `config.ru` file.

Once the repo is running you'll need to make sure port 3000/tcp is open and
available from your VM network.

## How to Use

Once you've met all your dependencies and have synced the repo. Change to the
root of this projects directory and run the following command:

```
thin start
```

The first run will create an escrow certificate and key that can be used to
decrypt the full disk encryption's escrow information after the fact.

To build a VM using my configuration and my kickstart template you can use the
`build_vm.sh` script, passing the VM's name as the first required argument and
optionally the amount of RAM, CPU cores, and disk size as the second, third,
and fourth parameters respectively. It does require root privileges (sudo
works).

The default ram amount is 512Mb, with 1 CPU core, and 15Gb of disk. The
kickstart file will auto-provision the partitions per RHEL6 NSA best practices,
encrypt the drive with a random password, set the root's password to a random
string and sets the bootloader password to a random string.

You can access all of the randomly generated passwords in the `passwords/`
directory with the most recent VM's passwords being available at
`passwords/latest.json`.

This file provides:

* When the VM was created
* The VM's IP address
* The VM's hostname
* The root password
* The Grub password
* The full disk encryption password
* The escrow'd encryption key and backup passphrase from the installer

**WARNING:** These files are all available to anyone who can access the
repository webserver! This poses a huge security risk if your VM's aren't
isolated.

## Repositories Mirrored

* CentOS 6.5 Primary Repositories
* EPEL RHEL 6 Repo
* PuppetLabs Yum Repo
* PostgreSQL 9.3 CentOS 6 Repo

## Future Work

In the future I may automate the creation of more of my development environment
including:

* Puppet Masters
* PostgreSQL databases
* Web Servers (Nginx)
* LXC Hosts
* Gateway / Router Machines
* Web proxies
* Mail servers (and catch-all servers)

