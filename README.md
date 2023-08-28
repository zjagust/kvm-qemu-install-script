# KVM QEMU Installation Script
This repository contains a script that will install KVM and QEMU. Script is intended as a support for the following article:

[KVM QEMU Installation & Configuration Guide](https://zacks.eu/kvm-qemu-installation-configuration)

## Installation
Clone this repository (or download zip file) and and execute the script by appending **sudo bash** (i.e., sudo bash kvm-qemu-autoinstall.sh). You can also copy the script to one of executable paths and run it from anywhere (leave out sudo if running as root):

> sudo cp kvm-qemu-autoinstall.sh /usr/local/sbin/kvm-qemu-autoinstall</br>
> sudo chown root:root /usr/local/sbin/kvm-qemu-autoinstall</br>
> sudo chmod 0755 /usr/local/sbin/kvm-qemu-autoinstall</br>
> sudo kvm-qemu-autoinstall

## Image pools & virtual networks
The script will remove the default image pool and the default network. New ones will be created.

### Image pools
The script will create the following dir based image pools:
  * Default images pool intended for guest virtual drives at */home/libvirt/vm_images*
  * ISO images pool intended for ISO installation media at */home/libvirt/iso_images*

### Virtual networks
The script will create the following virtual networks:
  * **Default NAT network with DHCP** (Interface: virbr0, Gateway: 172.16.0.1, Netmask: 255.255.255.255, DHCP Range: 172.16.0.2 - 172.16.0.255)
  * **Static NAT network** (no DHCP, Interface: virbr1, Gateway: 172.17.0.1, Netmask: 255.255.255.0, Start address: 172.17.0.2)
  * **Isolated network** (Interface: virbr2, requires a guest running as a "router")

## Helper scripts
As an option to this script, a helper scripts bundle can be installed (**-u** parameter). Bundle contains the following scripts:
  * **kvm-guest-actions**: Change guest state, manipulate snapshots and guest virtual disks and check guest basic network info
  * **kvm-debian-server-unattended**: Unattended installation of Debian Server guest machine, with all required checks and resources

You can find more details on helper scripts at: https://github.com/zjagust/kvm-qemu-install-script/blob/main/resources/README.md

## Options
Script has several options (parameters), and without supplying one it will just display help documentation. Following are the parameters:

**-h:** Print this help message<br>
**-r:** Check system readiness<br>
**-n:** Check how to enable Nesting (if -r shows it's disabled)<br>
**-z:** Check how to disable Zone Reclaim Mode (if -r shows it's enabled)<br>
**-s:** Check swappiness recommendations for your system<br>
**-d:** Check I/O scheduler recommendations for your disk devices<br>
**-i:** Install KVM QEMU. Recommended to run -r first<br>
**-u:** Install helper scripts bundle<br>