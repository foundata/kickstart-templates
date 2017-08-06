# Kickstart templates

This repository is used to provide template files for
[kickstart](https://en.wikipedia.org/wiki/Kickstart_(Linux)).

At this point in time, it is just a good starting point for further development
(by providing a solid, well commented base) and only used to assist manual
setup of our bare metal VM host machines.


### Tips and Trick

#### How to create CentOS 7 USB flash drive for installation

#### Preparations

  1. Download the DVD ISO from https://www.centos.org/download/. Do not forget
     to **verify the checksums**! Example:
     ```
     sha256sum ./CentOS-7-x86_64-DVD-1611.iso
     c455ee948e872ad2194bdddd39045b83634e8613249182b88f549bb2319d97eb  ./CentOS-7-x86_64-DVD-1611.iso
     ```
  2. In principle you can use any distribution you like. But using the same OS
     for media creation and target installation might save you from a lot
     trouble (e.g. incompatible syslinux versions and resulting c32 errors).
     So get a running box with the same OS version for USB installation media
     creation.

     * It might be clever to use the downloaded ISO to quickly setup a VM
       including GUI for this task. Just use USB passthrough then to access the
       USB flash drive.
     * Hints for Virtual Box and CentOS

       * You might want to enable USB 3 for faster copy operations afterwards.
       * Needed preparations to install guest additions:
         ```
         yum install @development
         yum update
         systemctl reboot
         ```



#### Media creation

Tasks:

  * Partitioning on the USB flash drive:

    1. `msdos` partition table
    2. `sdX1`: FAT32, label `KSBOOT`, no description, bootable, 350 MiB.
    3. `sdX2`: ext3, label `KSDATA`, no description, Rest of the storage (at
       least as large as the ISO).

  * Install syslinux on `/dev/sdX1` and copy `mbr.bin`
  * Copy syslinux bootmenu files from the ISO to `/dev/sdX1` (`KSBOOT`)
  * Copy ISO to `/dev/sdX2` (`KSDATA`)
  * Adapt `syslinux.cfg` on `KSBOOT` and place the `ks.cfg` beside

Full working example to execute under CentOS (all data on `sdX` will be lost!)
```
## define path of USB flash drive and ISO
TARGET='/dev/sdX'
ISOFILE='/path/to/centos/dvd.iso'

## verify
sha256sum "${ISOFILE}"

## partitioning
sudo fdisk "${TARGET}"
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
sudo mkfs.vfat -n 'KSBOOT' "${TARGET}1"
sudo mkfs.ext3 -L "KSDATA" "${TARGET}2"


## write MBR, install syslinux on boot partition
yum install syslinux
dd conv=notrunc bs=440 count=1 if='/usr/share/syslinux/mbr.bin' of="${TARGET}"
syslinux "${TARGET}1"


## copy data from ISO to USB flash drive
mkdir -p '/mnt/tmpkickstart/boot'
mkdir -p '/mnt/tmpkickstart/data'
mkdir -p '/mnt/tmpkickstart/iso'

mount "${TARGET}1" '/mnt/tmpkickstart/boot'
mount "${TARGET}2" '/mnt/tmpkickstart/data'
mount "${ISOFILE}" '/mnt/tmpkickstart/iso'

cp /mnt/tmpkickstart/iso/isolinux/* '/mnt/tmpkickstart/boot'
mv '/mnt/tmpkickstart/boot/isolinux.cfg' '/mnt/tmpkickstart/boot/syslinux.cfg'
cp "${ISOFILE}" '/mnt/tmpkickstart/data'
sync


## adapt labels for a fitting boot menu / to use kickstart file
# vi /mnt/tmpkickstart/boot/syslinux.cfg
# [...]
# See below for example


## copy your kickstart file on the USB flash drive
cp '/path/to/your/kickstart.file.ks' '/mnt/tmpkickstart/boot/ks.cfg'


## clean up
umount /mnt/tmpkickstart/*
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
https://access.redhat.com/solutions/2210981.



### Useful dev links, resources and notes

**Documentation:**

  * [RHEL7 Installation guide, 26.3. Kickstart Syntax Reference](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html)
  * [RHEL7 Installation guide, 5.8. Automating the Installation with Kickstart](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-installation-planning-kickstart-x86.html)
  * [RHEL 7 Anaconda Customization Guide, "3. Customizing the Boot Menu"](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/anaconda_customization_guide/sect-boot-menu-customization)
  * man dracut.cmdline


**Tools:**

  * https://github.com/coalfire/make-centos-bootstick
  * [pykickstart](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Migration_Planning_Guide/sect-Migration_Guide-Installation-Graphical_Installer-Kickstart-pykickstart.html) provides [tools](https://github.com/rhinstaller/pykickstart/tree/master/tools) like `ksvalidator` and `ksdiff`.
  * https://access.redhat.com/labsinfo/kickstartconfig -- but might be [broken](https://bugzilla.redhat.com/show_bug.cgi?id=1413292).


**Examples, inspiration:**

  * http://www.golinuxhub.com/2017/07/sample-kickstart-configuration-file-for.html -- useful examples, tips and tricks
  * https://github.com/rhinstaller/kickstart-tests
  * https://github.com/dapperlinux/dapper-kickstarts/blob/master/Kickstarts/fedora-live-workstation.ks
  * https://github.com/dapperlinux/dapper-kickstarts/blob/master/Kickstarts/snippets/packagekit-cached-metadata.ks
  * After installing a CentOS or Fedora box, you'll find the kickstart files Anaconda created by itself below `/root


**On `%pre`, `%post`, variables:**

  * https://serverfault.com/questions/608544/passing-variables-in-kickstart/609091#609091
  * http://red.ht/1Dos5ED
  * https://serverfault.com/questions/608544/passing-variables-in-kickstart
  * http://jacobjwalker.effectiveeducation.org/blog/2014/11/30/passing-variables-from-the-pre-to-post-scripts-in-kickstart-on-ubuntu/
  * http://www.golinuxhub.com/2017/07/sample-kickstart-configuration-file-for.html (at the end of the page)
  * http://www.golinuxhub.com/2017/05/how-to-perform-interactive-kickstart.html
  * `%pre` might write into `/tmp`, the kickstart does an `%include /tmp/foo`. Direct varpassing seems to be impossible, so one has to write complete kickstart commands. %pre can pass values to `%post` by using a ram disk (see links above for details) and you might user `%post` then to adapt the installation kickstart did. You might use multiple `%post` sections, with or without `--chroot` option to access the target system.
