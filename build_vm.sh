#!/bin/bash

NAME=${1}
RAM=${2:-512}
CPUS=${3:-1}
DISK_SIZE=${4:-15}

virt-install --connect qemu:///system --name "${NAME}" --ram "${RAM}" \
  --arch x86_64 --vcpus "${CPUS}" --security type=dynamic \
  --location http://10.64.89.1:3000/repo/centos/6.5/os/x86_64/ \
  --extra-args "text console=ttyS0 ks=http://10.64.89.1:3000/default-ks.cfg kssendmac" \
  --os-type=linux --os-variant=rhel6 \
  --disk="pool=default,size="${DISK_SIZE}",sparse=true,format=qcow2" \
  --network="network=cent" --graphics=none --hvm \
  --virt-type=kvm --accelerate --console=pty --memballoon=virtio --autostart \
  --check-cpu

