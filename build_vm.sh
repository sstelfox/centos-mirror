#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset

NAME=${1}
DISK_SIZE=${2:-15}
RAM=${3:-512}
CPUS=${4:-1}

virt-install --connect qemu:///system --name "${NAME}" --ram "${RAM}" \
  --arch x86_64 --vcpus "${CPUS}" --security type=dynamic \
  --location http://10.64.89.1:3000/repo/centos/6.5/os/x86_64/ \
  --extra-args "text console=ttyS0 ks=http://10.64.89.1:3000/default-ks.cfg kssendmac" \
  --os-type=linux --os-variant=rhel6 \
  --disk="pool=default,size="${DISK_SIZE}",sparse=true,format=qcow2" \
  --network="network=cent" --graphics=none --hvm \
  --virt-type=kvm --accelerate --console=pty --memballoon=virtio --autostart \
  --check-cpu --noautoconsole

MAC=$(virsh dumpxml "${NAME}" | grep 'mac address' | grep -Eio '[0-9a-f:]{17}')

curl -q -X POST -d "hostname=${NAME}" -d "mac=${MAC}" http://127.0.0.1:3000/register &> /dev/null

virsh console ${NAME}
sleep 1
virsh start ${NAME} --console

