#!/bin/bash

NAME=${1}

virsh destroy "${NAME}"
virsh undefine "${NAME}" --remove-all-storage
