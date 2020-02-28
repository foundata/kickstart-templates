# Kickstart templates

This repository is used to provide template files for
[kickstart](https://en.wikipedia.org/wiki/Kickstart_(Linux)).

At this point in time, it is just a good starting point for further development
(by providing a solid, well commented base) and only used to assist manual
setup of our bare metal VM host machines.


## HowTo, Tips and Trick


### Validate Kickstart file, show differences between versions

[pykickstart](https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html)
provides [tools](https://github.com/rhinstaller/pykickstart/tree/master/tools) like
`ksvalidator` and `ksdiff`. It makes sense to simply run them on the latest
Fedora release by installing the `pykickstart` package.

```
# install needed package
sudo dnf install pykickstart

# list available kickstart syntax versions
ksverdiff --list

# show differences
ksverdiff --from RHEL7 --to RHEL8

# validate a file
ksvalidator ./foo.ks
```


### CentOS 7/8: automatically load Kickstart file from `OEMDRV`storage device

The CentOS setup can load your Kickstart file automatically without having to
specify the `inst.ks=` boot option. To do so, one name the file `ks.cfg` and
place it on an additional storage volume labeled `OEMDRV` (cf. [RHEL 7
installation guide: 26.2.5. Starting the Kickstart Installation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-howto#sect-kickstart-installation-starting)).
One You can use ext2/3/4 or XFS as filesystem.


The following explains how to prepare [prepare a USB key with label `OEMDRV`](https://docs.centos.org/en-US/8-docs/advanced-install/assembly_making-kickstart-files-available-to-the-installation-program/#making-a-kickstart-file-available-on-a-local-volume-for-automatic-loading_making-kickstart-files-available-to-the-installation-program) on the terminal (`gparted` as UI would also be sufficient):

```
## define path of USB flash drive
lsblk -l -p
TARGETDEVICE='/dev/sdX'
KICKSTARTFILE='/path/to/your/kickstart.file.ks'

## partitioning
sudo parted "${TARGETDEVICE}" mktable msdos
sudo parted "${TARGETDEVICE}" mkpart primary 0% 100%

## create filesystem and label it
# Hint if you need to manually adjust the label of an existing filesystem:
# ext2/3/4:   e2label "${TARGETDEVICE}1" 'OEMDRV'
# cfs:        xfs_admin -L 'OEMDRV' "${TARGETDEVICE}1"
sudo mkfs.xfs -f -L 'OEMDRV' "${TARGETDEVICE}1"
lsblk -l -p

## copy your kickstart file on the USB flash drive
sudo mkdir -p '/mnt/tmpkickstart/'
sudo mount "${TARGETDEVICE}1" '/mnt/tmpkickstart/'
sudo cp "${KICKSTARTFILE}" '/mnt/tmpkickstart/ks.cfg'
sudo chmod 0664 '/mnt/tmpkickstart/ks.cfg'

## clean up
sync
sudo umount /mnt/tmpkickstart/
sudo rm -rf "/mnt/tmpkickstart/"
```


Now just boot and make sure the additional USB key is present when the installation media starts.



### CentOS 7/8: Create USB flash drive installation media

Just validate your ISO and write it with `dd` to the target device `/dev/sdX`
(adapt as needed). For sure, all data (if any) on the target will get detroyed.

Example:

```
$ sha256sum ./CentOS-8.1.1911-x86_64-dvd1.iso
3ee3f4ea1538e026fff763e2b284a6f20b259d91d1ad5688f5783a67d279423b  ./CentOS-8.1.1911-x86_64-dvd1.iso

$ sudo dd if=./CentOS-8.1.1911-x86_64-dvd1.iso of=/dev/sdX bs=8M status=progress oflag=direct && sync
```


### Debugging Hints

After Anaconda (the graphical installer) started, there are differen TTYs /
terminals you can switch to (via Ctrl+Alt+F<Number> ort Alt+F<Number>):

* **TTY1:** Main information screen before starting the graphical installer
  (Anaconda). As well as the installation dialog when using `text` or `cmdline`.
* **TTY2:** A root shell. Useful commands and hints:
  * `/tmp/ks-script-XXX`: A script defined in `%pre`. So you can inspect or
    (re-)run.
  * A Kickstartfile from a `OEMDRV` gets copied to `/run/install/ks.cfg`. If
    nothing exists, check if `mkdir /run/foo && mount /dev/sdX1 /run/foo`
    works.
  * `lsblk -l -p`
* **TTY3**
  * The install log displaying messages from install program
* **TTY4**
  * The system log displaying messages from kernel, etc.
* **TTY5**
  * All other messages
* **TTY7**
  * The installation dialog when using the graphical installer.


### CentOS 7: Custom USB flash drive including the Kickstart file for installation

Attention: the following method will only work with **Legacy BIOS boot**. The
USB Flash drive **will not boot with UEFI**.

#### Preparations

Download the DVD ISO from <https://www.centos.org/download/>. Do not forget
to **verify the checksums**! Example:

```
sha256sum ./CentOS-7-x86_64-DVD-1611.iso
c455ee948e872ad2194bdddd39045b83634e8613249182b88f549bb2319d97eb  ./CentOS-7-x86_64-DVD-1611.iso
```

In principle you can use any distribution you like. But using the same OS
for media creation and target installation might save you from a lot trouble
(e.g. incompatible syslinux versions and resulting c32 errors).

So get a running box with the same OS version for USB installation media
creation (It might be clever to just use the downloaded ISO to quickly setup a
VM including GUI for this task. Use USB passthrough then to access the USB
flash drive).

Hints for Virtual Box and CentOS:

* You might want to enable USB 3 for faster copy operations afterwards.
* USB 3 devices do not work on virtual USB 2 controllers (so the VirtualBox
  extension pack is needed then).
* [Install guest additions](https://www.if-not-true-then-false.com/2010/install-virtualbox-guest-additions-on-fedora-centos-red-hat-rhel/):
  ```
  # Preparation
  sudo yum install epel-release
  sudo yum install gcc kernel-devel kernel-headers dkms make bzip2 perl
  sudo yum update
  sudo systemctl reboot

  # Install
  export KERN_DIR=/usr/src/kernels/`uname -r`
  # [... insert Guest addition media now and follow the instructions of
  #     ./VBoxLinuxAdditions.run ... ]
  ```

#### Media creation

Tasks:

* Partitioning on the USB flash drive:
  1. `msdos` partition table
  2. `sdX1`: FAT32, label `KSBOOT`, no description, bootable, 350 MiB.
  3. `sdX2`: ext3, label `KSDATA`, no description, Rest of the storage (at
      least as large as the ISO).
* Install [SYSLINUX](https://en.wikipedia.org/wiki/SYSLINUX) on `/dev/sdX1`
  and copy `mbr.bin`
* Copy the SYSLINUX bootmenu files from the ISO to `/dev/sdX1` (`KSBOOT`)
* Copy ISO to `/dev/sdX2` (`KSDATA`)
* Adapt `syslinux.cfg` on `KSBOOT` and place the `ks.cfg` beside

Full working example to execute under CentOS (all data on `sdX` will be lost!)
```
## define path of USB flash drive and ISO
TARGETDEVICE='/dev/sdX'
ISOFILE='/path/to/centos/dvd.iso'
KICKSTARTFILE='/path/to/your/kickstart.file.ks'

## verify
sha256sum "${ISOFILE}"

## partitioning
sudo fdisk "${TARGETDEVICE}"
o
    Building a new DOS disklabel with disk identifier 0x94a6972d.
n
    Partition type:
       p   primary (0 primary, 0 extended, 4 free)
       e   extended
    Select (default p):
    Using default response p
    Partition number (1-4, default 1):
    First sector (2048-30869503, default 2048):
    Using default value 2048
    Last sector, +sectors or +size{K,M,G} (2048-30869503, default 30869503): +350M
    Partition 1 of type Linux and of size 350 MiB is set
t
    Selected partition 1
    Hex code (type L to list all codes): c
    Changed type of partition 'Linux' to 'W95 FAT32 (LBA)'
a
    Selected partition 1
n
    Partition type:
       p   primary (1 primary, 0 extended, 3 free)
       e   extended
    Select (default p):
    Using default response p
    Partition number (2-4, default 2):
    First sector (718848-30869503, default 718848):
    Using default value 718848
    Last sector, +sectors or +size{K,M,G} (718848-30869503, default 30869503): +5000M
    Partition 2 of type Linux and of size 4.9 GiB is set
w
    The partition table has been altered!

## create file systems
sudo mkfs.vfat -n 'KSBOOT' "${TARGETDEVICE}1"
sudo mkfs.ext3 -L "KSDATA" "${TARGETDEVICE}2"


## write MBR, install syslinux on boot partition
sudo yum install syslinux
sudo dd conv=notrunc bs=440 count=1 if='/usr/share/syslinux/mbr.bin' of="${TARGETDEVICE}"
syslinux "${TARGETDEVICE}1"


## copy data from ISO to USB flash drive
mkdir -p '/mnt/tmpkickstart/boot'
mkdir -p '/mnt/tmpkickstart/data'
mkdir -p '/mnt/tmpkickstart/iso'

sudo mount "${TARGETDEVICE}1" '/mnt/tmpkickstart/boot'
sudo mount "${TARGETDEVICE}2" '/mnt/tmpkickstart/data'
sudp mount "${ISOFILE}" '/mnt/tmpkickstart/iso'

cp /mnt/tmpkickstart/iso/isolinux/* '/mnt/tmpkickstart/boot'
mv '/mnt/tmpkickstart/boot/isolinux.cfg' '/mnt/tmpkickstart/boot/syslinux.cfg'
cp "${ISOFILE}" '/mnt/tmpkickstart/data'
sync


## adapt labels for a fitting boot menu / to use kickstart file
vi /mnt/tmpkickstart/boot/syslinux.cfg
# [...]
# See below for example


## copy your kickstart file on the USB flash drive
cp "${KICKSTARTFILE}" '/mnt/tmpkickstart/boot/ks.cfg'


## clean up
sudo umount /mnt/tmpkickstart/*
rm -rf "/mnt/tmpkickstart/"
```

Example syslinux labels:

```
# The inst.gpt boot parameter forces a GPT partition table even when the disk
# size is less than 2^32 sectors, cf. red.ht/2psiz5w.

label kickstart
  menu label ^Install CentOS (Kickstart)
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=KSDATA:/ ks=hd:LABEL=KSBOOT:/ks.cfg inst.gpt quiet

label kickstartcheck
  menu label Test this ^media & install CentOS (Kickstart)
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=KSDATA:/ ks=hd:LABEL=KSBOOT:/ks.cfg inst.gpt rd.live.check quiet
```

See [RHEL 7 Anaconda Customization Guide,
"3. Customizing the Boot Menu"](https://red.ht/2u9wXBU) and `man dracut.cmdline`
for more details and documentation.

The `inst.gpt` boot parameter forces a GPT partition table
even when the disk size is less than 2^32 sectors, cf.
<https://access.redhat.com/solutions/2210981>.



## Further reading, useful links and notes

**Documentation:**

* [RHEL 7 Installation guide, 26.3. Kickstart Syntax Reference](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html)
* [RHEL 7 Installation guide, 5.8. Automating the Installation with Kickstart](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-installation-planning-kickstart-x86.html)
* [RHEL 7 Anaconda Customization Guide, "3. Customizing the Boot Menu"](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/anaconda_customization_guide/sect-boot-menu-customization)
* `man dracut.cmdline`
* [RHEL 8 Installation Guide: Appendix A. Kickstart script file format reference](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-script-file-format-reference_installing-rhel-as-an-experienced-user)
  * Especcially [A.2. Package selection in Kickstart](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/performing_an_advanced_rhel_installation/kickstart-script-file-format-reference_installing-rhel-as-an-experienced-user#package-selection-in-kickstart_kickstart-script-file-format-reference)
* [CentOS 8: Starting Kickstart installations](https://docs.centos.org/en-US/8-docs/advanced-install/assembly_starting-kickstart-installations/)


**Tools:**

* https://github.com/coalfire/make-centos-bootstick
* https://github.com/coalfire/cent-mkiso
* [pykickstart](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Migration_Planning_Guide/sect-Migration_Guide-Installation-Graphical_Installer-Kickstart-pykickstart.html) provides [tools](https://github.com/rhinstaller/pykickstart/tree/master/tools) like `ksvalidator` and `ksdiff`.
* https://access.redhat.com/labsinfo/kickstartconfig -- but might be [broken](https://bugzilla.redhat.com/show_bug.cgi?id=1413292).
* https://access.redhat.com/labsinfo/kickstartconvert
* https://github.com/Scout24/kickstart-debugger


**Examples, inspiration:**

* http://www.golinuxhub.com/2017/07/sample-kickstart-configuration-file-for.html -- useful examples, tips and tricks
* https://github.com/rhinstaller/kickstart-tests
* https://github.com/dapperlinux/dapper-kickstarts/blob/master/Kickstarts/fedora-live-workstation.ks
* https://github.com/dapperlinux/dapper-kickstarts/blob/master/Kickstarts/snippets/packagekit-cached-metadata.ks
* After installing a CentOS or Fedora box, you'll find the kickstart files Anaconda created by itself below `/root`. You will also find some files below `/examples` in this repo.


**On `%pre`, `%post`, variables:**

* [Passing variables in kickstart](https://serverfault.com/questions/608544/passing-variables-in-kickstart), especially [answer 609091](https://serverfault.com/questions/608544/passing-variables-in-kickstart/609091#609091)
* [RHEL 7 Installation guide, 26.3. Kickstart Syntax Reference](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html)
  * [Passing Variables from the %Pre to %Post scripts in Kickstart on Ubuntu](http://jacobjwalker.effectiveeducation.org/blog/2014/11/30/passing-variables-from-the-pre-to-post-scripts-in-kickstart-on-ubuntu/)
  * http://www.golinuxhub.com/2017/07/sample-kickstart-configuration-file-for.html (at the end of the page)
  * http://www.golinuxhub.com/2017/05/how-to-perform-interactive-kickstart.html
  * `%pre` might write into `/tmp`, the kickstart does an `%include /tmp/foo`. Direct varpassing seems to be impossible, so one has to write complete kickstart commands. %pre can pass values to `%post` by using a ram disk (see links above for details) and you might user `%post` then to adapt the installation kickstart did. You might use multiple `%post` sections, with or without `--chroot` option to access the target system.
