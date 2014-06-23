#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset

NAME=${1}
DISK_SIZE=${2:-20}
RAM=${3:-4096}
CPUS=${4:-2}

virt-install --connect qemu:///system --name "${NAME}" --ram "${RAM}" \
  --arch x86_64 --vcpus "${CPUS}" --security type=dynamic \
  --location http://10.64.89.1:3000/repo/centos/6.5/os/x86_64/ \
  --extra-args "text console=ttyS0 ks=http://10.64.89.1:3000/default-ks.cfg?hostname='${NAME}' kssendmac" \
  --os-type=linux --os-variant=rhel6 \
  --disk="pool=default,size="${DISK_SIZE}",sparse=true,format=qcow2" \
  --network="network=cent" --graphics=none --hvm \
  --virt-type=kvm --accelerate --console=pty --memballoon=virtio --autostart \
  --check-cpu --noautoconsole

sleep 2
virsh console ${NAME}
sleep 2
virsh start ${NAME} --console

