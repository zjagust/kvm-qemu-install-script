# KVM QEMU Installation Script Resources

This collection of bundled resources complements the main KVM/QEMU installation. Resources in this bundle can be periodically updated, and new resources may be added. The purpose of this bundle is to ease the work and administration of the KVM/QEMU virtualization system. 

**Disclamer**<br>
Resources in this bundle are fully compatible with the system set by the main KVM/QEMU script. Yet, they might not work on other similar KVM/QEMU systems without prior modifications. The usage on such systems is not recommended.

## Resources Collection
### KVM Guest Actions
This resource contains the script **kvm-guest-actions**, which will install at */usr/local/sbin/kvm-guest-actions*, and a XSL file **guest_storage_list.xsl** installed at */etc/libvirt/qemu/guest_storage_list.xsl*. The purpose of the XSL file is to help parse the XML configuration file of all guests (virtual machines) and extract relevant information about storage used by guests.

The script has multiple parameters described below (use **sudo** if not root):

* **-H**: Print this help message
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
