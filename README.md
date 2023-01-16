# KVM QEMU Installation Script
This repository contains a script that will install KVM and QEMU. Script is intended as a support for the following article:

[KVM QEMU Installation & Configuration Guide](https://zacks.eu/kvm-qemu-installation-configuration)

## Installation
Clone this repository (or download zip file) and and execute the script by appending **sudo bash** (i.e., sudo bash kvm-qemu-autoinstall.sh). You can also copy the script to one of executable paths and run it from anywhere:

<code>
$> sudo cp kvm-qemu-autoinstall.sh /usr/local/sbin/kvm-qemu-autoinstall<br>
$> kvm-qemu-autoinstall
</code>

## Options
Script has several options (parameters), and without supplying one it will just display help documentation. Following are the parameters:

-h: Print this help message<br>
-r: Check system readiness<br>
-n: Check how to enable Nesting (if -r shows it's disabled)<br>
-z: Check how to disable Zone Reclaim Mode (if -r shows it's enabled)<br>
-s: Check swappiness recommendations for your system<br>
-d: Check I/O scheduler recommendations for your disk devices<br>
-i: Install KVM QEMU. Recommended to run -r first<br>