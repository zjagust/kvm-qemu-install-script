# KVM QEMU Installation Script Resources

This collection of bundled resources complements the main KVM/QEMU installation. Resources in this bundle can be periodically updated, and new resources may be added. The purpose of this bundle is to ease the work and administration of the KVM/QEMU virtualization system. 

**Disclamer**<br>
Resources in this bundle are fully compatible with the system set by the main KVM/QEMU script. Yet, they might not work on other similar KVM/QEMU systems without prior modifications. The usage on such systems is not recommended.

## Resources Collection
### KVM Guest Actions
This resource contains the script **kvm-guest-actions**, which will install at */usr/local/sbin/kvm-guest-actions*, and a XSL file **guest_storage_list.xsl** installed at */etc/libvirt/qemu/guest_storage_list.xsl*. The purpose of the XSL file is to help parse the XML configuration file of all guests (virtual machines) and extract relevant information about storage used by guests.

The script has multiple parameters described below (use **sudo** if not root):

* **-H**: Print help message
    * *-> (usage: kvm-guest-actions -H)*
* **-S CHANGE GUEST STATE**
  * **-Sd** to show GUEST_NAMES
  * **-Ss** GUEST_NAME to start guest
  * **-Sh** GUEST_NAME to shutdown guest
  * **-Sr** GUEST_NAME to reboot guest
  * **-Sp** GUEST_NAME to completely purge guest
    * *-> (usage: kvm-guest-actions -Ss -Sh -Sr -Sp GUEST_NAME, or kvm-guest-actions -Sd)*
* **-D: DISPLAY/CREATE/APPLY/DELETE GUEST SNAPSHOT**
  * **-Di** GUEST_NAME to list snapshots and SNAPSHOT_TAG
  * **-Dc** GUEST_NAME SNAPSHOT_NAME to create snapshot
  * **-Da** GUEST_NAME SNAPSHOT_TAG to apply snapshot
  * **-Dd** GUEST_NAME SNAPSHOT_TAG to delete shapshot
    * *-> (usage: kvm-guest-actions -Di GUEST_NAME, or kvm-guest-actions -Dc GUEST_NAME SNAPSHOT_NAME, or kvm-guest-actions -Da -Dd GUEST_NAME SNAPSHOT_TAG)*
* **-V: DISPLAY/CREATE&ATTACH/ATTACH/DETACH/DELETE GUEST VIRTUAL DRIVES**
  * **-Vl** GUEST_NAME to list attached virtual drives
  * **-Vc** GUEST_NAME IMAGE_NAME IMAGE_SIZE (in MiB) to create and optionally attach a new virtual disk
  * **-Va** GUEST_NAME to attach already existing image from default pool
  * **-Vd** GUEST_NAME to detach disk image
  * **-Vp** to delete virtual disk
    * *-> (usage: kvm-guest-actions -Vl -Va -Vd GUEST_NAME, or kvm-guest-actions -Vc GUEST_NAME IMAGE_NAME IMAGE_SIZE (in MiB), or kvm-guest-actions -Vp)* 
* **-N: DISPLAY GUEST NETWORK INFO (interfaces/MACs/IPs)**
  * **-N** GUEST_NAME name to list active interface(s) info
    * *-> (usage: kvm-guest-actions -N GUEST_NAME)*

### Debian Server Unattended Install
This resource contains the script **kvm-debian-server-unattended**, which will install at */usr/local/sbin/kvm-debian-server-unattended*. Along with the script, the following resources will be set:

* Preseed configuration files **debian-server-dhcp-pressed.cfg** and **debian-server-static-preseed.cfg** will be placed to */etc/libvirt/qemu/preseed* directory.
* Preseed late-install script **debian-server-late-install.sh** and basic firewall configuration file **basic-firewall** will be place to */etc/libvirt/qemu/late-install* directory.
* On the first run, **kvm-debian-server-unattended** script will create an inventory file at */etc/libvirt/qemu/installed-guests.csv*.

The script has multiple parameters described below (use **sudo** if not root):

* **-h**: Print help message
    * *-> (usage: kvm-debian-server-unattended -h)*
* **-l**: List inventory (all guest machines)
    * *-> (usage: kvm-debian-server-unattended -l)*
* **-s**: List supported Debian distributions
    * *-> (usage: kvm-debian-server-unattended -s)*
* **-n**: List available virtual networks
    * *-> (usage: kvm-debian-server-unattended -n)*
* **-i**: Install Debian Server guest machine
  * The following parameters must be defined if DHCP network is used: **guest name**, **disk size**, **RAM size**, **VCPU count**, **distro name**, **virtual network name**, **root password** 
    * *-> (usage: kvm-debian-server-unattended -i debian 10240 2048 2 bookworm default-nat-dhcp passpass)*
  * The following parameters must be defined if Static network is used: **guest name**, **disk size**, **RAM size**, **VCPU count**, **distro name**, **virtual network name**, **root password**, **static ip address**
    * *-> (usage: kvm-debian-server-unattended -i debian 10240 2048 2 bookworm default-nat-static passpass 172.17.0.X)*