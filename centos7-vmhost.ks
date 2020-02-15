#version=DEVEL


#### Pre-install scripts
#
# Attention: Kickstart commands do NOT run until *after* the %pre section,
#            despite the ordering in the kickstart file.
#
# Notes:
# - Exchanging data between %pre and %post is possible via custom ramdisk.
# - Exchanging data between %pre and kickstart is possible by writing kickstart
#   code in file below /tmp/, using %import on them afterwards.
# - You cannot change anything on the not-yet-installed system here.
#   If really needed, "%post --nochroot" might help.
# - RHEL 7 Installation Guide, 26.3.3. Pre-installation Script, red.ht/2uUrzzU


%pre
# Switch to /dev/tty6 (tty = TeleTYpewriter) for text console, redirect all
# input and output, make /dev/tty6 the foreground terminal and start a shell
# on it. The graphical interface (and therefore Anaconda) lives on /dev/tty1.
exec < /dev/tty6 > /dev/tty6 2> /dev/tty6
chvt 6


# define regular expressions for input validation
readonly regex_hostname='^[[:lower:]]([[:lower:][:digit:]\-]{0,61}[[:lower:][:digit:]])?$'
readonly regex_domainname='^[[:lower:][:digit:]][[:lower:][:digit:]\-\.]{1,252}[[:lower:][:digit:]]$' # some domain NICs allow leading numbers and stuff; we cannot be stricter than them if we won't refuse really existing domains
readonly regex_dmcryptpwd='^[[:alnum:][:punct:]]{20,}$' # ATTENTION: has to stricter or in sync than kickstart cmd "pwpolicy luks".

# init misc vars
data_hostname=''
data_domainname=''
data_drive=''
data_dmcrypt_pwdplain=''
data_packages_vmhostgui=''


# This kickstart file is just a helper, configuring *most* but not *all* things.
# So the %pre-script tries to avoid asking for data a preconfiguration is not
# really useful and/or Anaconda is providing a accessible and sane UI for.
#
# Therefore we are NOT asking for the following things here:
# - Name of network device (hint: if needed some day, device list from
#   /sys/class/net might be useful)
# - root password
# - user to create: username and password
# - timezone
#
# Not setting the "timezone" kickstart command is also a little trick. It
# prevents Anaconda from starting the installation automatically. This enables
# the user to use the UI to adapt misc settings before the installation happens.
# Might be useful from time to time, especially regarding network settings.


# ask for the hostname
if [ -z "${data_hostname}" ]
then
    printf 'Step 1: hostname (a.k.a. "machine name")\n\n'
    printf '%s\n' 'Naming rules: The hostname is restricted to lowercase alphanumeric characters' \
                  'and hyphens. It has to have 1-63 chars, start with a letter and must not end' \
                  'with a hyphen; that is, a hostname has to match the following pattern:' \
                  '"^[a-z]([a-z0-9\-]{0,61}[a-z0-9])?$"'
    printf '\n'

    # suggest pseudo-random name
    valsuggestion=''
    while [ -z "${valsuggestion}" ]
    do
        valsuggestion=$(cat /proc/sys/kernel/random/uuid | cut -c 26-30 | grep -E -e '^[a-f][a-f0-9]{1,5}$')  # "uuidgen" cmd is not available
    done
    if [ -z "${valsuggestion}" ]
    then
        printf '%s\n' 'Please enter the hostname to use for this system (without domain name):'
    else
        printf '%s\n' 'Please enter the hostname to use for this system (without domain name)' \
                      "(just press [ENTER] for "${valsuggestion}"):"
    fi
    printf '> '
    while IFS= read -r data_hostname
    do
        # if user just pressed [ENTER]: use suggestion?
        if [ -z "${data_hostname}" ] &&
           [ -n "${valsuggestion}" ]
        then
            data_hostname="${valsuggestion}"
            printf 'Using "%s".\n' "${data_hostname}"
        fi
        # check data
        if [ -n "${data_hostname}" ] &&
           printf '%s' "${data_hostname}" | grep -E -q -e "${regex_hostname}"
        then
            break 1 # input was valid
        fi
        if [ -n "${valsuggestion}" ] &&
           [ "${valsuggestion}" = "${data_hostname}" ]
        then
            # do not re-propose the value if it was invalid
            valsuggestion=''
        fi
        # re-ask
        printf '\n'
        if [ -z "${valsuggestion}" ]
        then
            printf '%s\n' 'Error: Your input is no valid hostname (cf. "Naming rules" above).' \
                          'Please try it again:'
        else
            printf '%s\n' 'Error: Your input is no valid hostname (cf. "Naming rules" above).' \
                          "Please try it again (just press [ENTER] for \"${valsuggestion}\"):"
        fi
        printf '> '
    done
    unset valsuggestion
    printf '\n\n'
fi


# ask for the domainname
if [ -z "${data_domainname}" ]
then
    printf "Step 2: domain name\n\n"
    printf '%s\n' 'The domain name to use for this system. You may want to enter "localdomain",' \
                  '"lan" or "site" if you do not have a real domain like "example.com".'
    # The "real" DNS label naming rules are stricter. But some NICs are a
    # bit lax (e.g. they allow leading numbers and things like that). So we
    # cannot be stricter than by refusing really existing domains here.
    printf '\n'
    printf '%s\n' 'Naming rules: The domain name consist of DNS labels, each one separated by' \
                  'a dot. Each label is restricted to lowercase alphanumeric characters and' \
                  'hyphens; that is, your domain name have to match the following pattern:' \
                  '"^[a-z0-9\-\.]{1,253}[a-z0-9]$."'
    printf '\n'

    valsuggestion="localdomain"
    if [ "${valsuggestion}" = 'test' ] ||      # reserved (RFC 2606)
       [ "${valsuggestion}" = 'example' ] ||   # reserved (RFC 2606)
       [ "${valsuggestion}" = 'invalid' ] ||   # reserved (RFC 2606)
       [ "${valsuggestion}" = 'localhost' ] || # reserved (RFC 2606)
       ! printf '%s' "${valsuggestion}" | grep -E -q -e "${regex_domainname}"
    then
        valsuggestion=''
    fi
    fqdntest="${data_hostname}.${valsuggestion}." # create FQDN (inkl. trailing dot) to check the over all length
    if [ "${#fqdntest}" -gt 255 ]
    then
        valsuggestion=''
    fi
    if [ -z "${valsuggestion}" ]
    then
        printf '%s\n' 'Please enter the domain name to use for this system:'
    else
        printf '%s\n' 'Please enter the domain name to use for this system (just press' \
                      "[ENTER] for \"${valsuggestion}\"):"
    fi
    printf '> '
    while IFS= read -r data_domainname
    do
        # if user just pressed [ENTER]: use suggestion?
        if [ -z "${data_domainname}" ] &&
           [ -n "${valsuggestion}" ]
        then
            data_domainname="${valsuggestion}"
            printf 'Using "%s".\n' "${data_domainname}"
        fi
        data_domainname="$(printf '%s' "${data_domainname}" | sed -e 's/^\.//' -e 's/\.$//')" # strip leading and trailing dots
        fqdntest="${data_hostname}.${data_domainname}." # create FQDN (inkl. trailing dot) to check the over all length
        # check data (and inform about the type of error, if any).
        if [ "${data_domainname}" = 'test' ] ||    # reserved (RFC 2606)
           [ "${data_domainname}" = 'example' ] || # reserved (RFC 2606)
           [ "${data_domainname}" = 'invalid' ] || # reserved (RFC 2606)
           [ "${data_domainname}" = 'localhost' ]  # reserved (RFC 2606)
        then
            printf '%s\n' 'Error: The domain names "test", "example", "invalid" and "localhost" are' \
                          'reserved (cf. RFC 2606, http://tools.ietf.org/html/rfc2606). Therefore you' \
                          "cannot use \"${data_domainname}\"."
        elif [ "${#fqdntest}" -gt 255 ] &&
             printf '%s' "${data_domainname}" | grep -E -q -e "${regex_domainname}"
        then
            printf '%s\n' 'Error: Your domain name itself is valid but the resulting fully qualified' \
                          "domain name (FQDN) (-> \"${data_hostname}.your-domainname.\") has to be" \
                          'shorter than 256 chars.'
        elif ! printf '%s' "${data_domainname}" | grep -E -q -e "${regex_domainname}"
        then
            printf '%s\n' 'Error: Your input is no valid/useable domain name (cf. "Naming rules" above).'
        else
            # warn in case of 'local' domain but let him decide what to do
            if [ "${data_domainname}" = 'local' ]
            then
                printf '%s\n' 'Warning: You should NOT use "local" as domain name. For example, the .local' \
                              'TLD is used for mDNS and other zero-conf-services.'
                printf 'Do you really want to use "local" as domain name? [y|n]: '
                if { IFS= read -r in; printf '%s' "${in}"; } | grep -E -q -e "$( (command -v 'locale' && locale yesexpr) || printf '^[jJyY].*')"
                then
                    printf 'Using "%s".\n' "${data_domainname}"
                    break 1 # input was valid
                fi
            else
                break 1 # input was valid
            fi
        fi
        if [ -n "${valsuggestion}" ] &&
           [ "${valsuggestion}" = "${data_domainname}" ]
        then
            # do not re-propose the value if it was invalid
            valsuggestion=''
        fi
        # re-ask
        printf '\n'
        if [ -z "${valsuggestion}" ]
        then
            printf '%s\n' 'Please try it again. Enter the domain name to use for this system:'
        else
            printf '%s\n' 'Please try it again. Enter the domain name to use for this system (just' \
                          "press [ENTER] for \"${valsuggestion}\"):"
        fi
        printf '> '
    done
    unset valsuggestion fqdntest
    printf '\n\n'
fi


# ask for the installation target disk
if [ -z "${data_drive}" ]
then
    printf "Step 3: installation target\n\n"

    # get sorted list of avaible disk names, separated by tab
    list_drives="$(printf '%s' "$(lsblk -d | grep -F -i -e 'disk' | sort | cut -d ' ' -f 1 | tr "\n" "\t")" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    drivecount="$(printf '%s' "${list_drives}" | sed "s/[^$(printf '\t')]//g" | tr -d '\n' | wc -m)" # strip "chars!=seperator", count remaining
    drivecount="$((${drivecount}+1))"
    while [ -z "${data_drive}" ]
    do
        if [ "${drivecount}" -lt 1 ] ||
           [ -z "${list_drives}" ]
        then
            printf '%s\n\n' 'Error: no disk drives found.'
        elif [ "${drivecount}" -eq 1 ]
        then
            data_drive="$(printf '%s' "${list_drives}" | cut -f 1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            printf '%s\n' "There is only one available drive, therefore nothing to choose. Using \"${data_drive}\"."
        else
            printf '%s\n\n' 'Available installation targets:'
            i='0'
            ifs_save="${IFS}"; IFS="$(printf '\t')" # temporarily change IFS to "\t" (tab)
            for resource in ${list_drives}
            do
                i="$((${i}+1))"
                printf "  %2u: %s\n" "${i}" "$(awk "/${resource}$/{printf \"%5s %8.2f GiB\n\", \$NF, \$(NF-1) / 1024 / 1024}" '/proc/partitions')"
            done
            IFS="${ifs_save}"; unset ifs_save # restore IFS
            unset i resource
            printf '\n%s\n' 'Please choose a target installation drive by typing the associated number:'
            printf '> '
            choice_drive=''
            while IFS= read -r choice_drive
            do
                # check data
                choice_drive="$(printf '%s' "${choice_drive}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                if [ -n "${choice_drive}" ] &&
                   printf '%s' "${choice_drive}" | grep -E -q -e '^[[:digit:]]*$' &&
                   [ "${choice_drive}" -ge 1 ] &&
                   [ "${choice_drive}" -le "${drivecount}" ]
                then
                    break 1 # input was valid
                fi
                # re-ask
                printf 'Error: you have to choose a number between 1 and %d:\n' "${drivecount}"
                printf '> '
            done
            data_drive="$(printf '%s' "${list_drives}" | cut -f "${choice_drive}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            unset choice_drive
            printf 'Using "%s".\n' "${data_drive}"
        fi
    done
    printf '\n\n'
fi


# ask if system should be encrypted and for the disk encryption password to use
#
# Notes on terminology:
# - DM-Crypt: The kernel's disk encryption subsystem (module "dm-crypt")
# - LUKS: Specification and format of on-disk encryption designed for use with
#   dm-crypt.
# - Device Mapper: The disk framework that creates virtual block device to
#   physical block device mappings (cf. /dev/mapper/)
# - cryptsetup: Binary tool used to manage encrypt disks
if [ -z "${data_dmcrypt_pwdplain}" ]
then
    printf 'Step 4: disk encryption (dm-crypt/LUKS) \n\n'
    printf 'Do you want to use full disk encryption?  [y|n]: '
    if { IFS= read -r i; printf '%s' "${i}"; } | grep -E -q -e "$( (command -v 'locale' && locale yesexpr) || printf '^[jJyY].*')"
    then
        printf '\n'
        printf '%s\n' 'Password rules: Use a passphrase which is at least 20 chars long and does not' \
                      'contain whitespace. It has to match the following pattern:' \
                      '^[a-zA-Z!"\#$%&'\''()*+,\-./:;<=>?@\[\\\]^_`{|}~]{20,}$'
        printf '\n'

        pwdconfirm=''
        pwdscore=''
        printf '%s\n' 'Password input will not be shown on the screen (no echo).'
        printf '%s' 'Please enter password:'
        while IFS= read -r -s data_dmcrypt_pwdplain # ATTENTION: read -s is not POSIX compliant but a Bash extension. Using it here only because stty and tput is not available.
        do
            printf '\n'

            # get password quality score
            pwdscore="$(printf '%s' \"${data_dmcrypt_pwdplain}\" | pwscore 2> /dev/null)"
            if [ -z "${pwdscore}" ]
            then
                pwdscore='0'
            fi

            # check quality
            if [ -z "${data_dmcrypt_pwdplain}" ]
            then
                printf '%s\n' 'Error: Empty passwords are not allowed.'
            elif [ -z "${pwdscore}" ] ||
                 [ "${pwdscore}" -lt 50 ] # ATTENTION: has to stricter or in sync than kickstart cmd "pwpolicy luks"
            then
                printf '%s\n' "Error: Password is too weak (cf. \"Password rules\" above). pwscore result: ${pwdscore}"
            elif ! printf '%s' "${data_dmcrypt_pwdplain}" | grep -E -q -e "${regex_dmcryptpwd}"
            then
                printf '%s\n' 'Error: Password does not match the allowed pattern (cf. "Password rules" above).' \
                              '       Any invalid chars? Too short?'

            # password confirmation
            elif [ -n "${data_dmcrypt_pwdplain}" ]
            then
                printf '%s' 'Please confirm password:'
                IFS= read -r -s pwdconfirm # ATTENTION: read -s is not POSIX compliant but a Bash extension. Using it here only because stty and tput is not available.
                printf '\n'
                if  [ "${data_dmcrypt_pwdplain}" != "${pwdconfirm}" ]
                then
                    printf '%s\n' 'Error: Passwords do not match.'
                    pwdconfirm=''
                else
                     break 1 # input was valid
                fi
            fi

            # re-ask
            printf '\n%s' 'Please enter password:'
        done
        unset pwdconfirm
    else
        printf 'Ok, system will be unencrypted.\n'
    fi
    printf '\n\n'
fi


# ask if there should be a GUI or not
if [ -z "${data_packages_vmhostgui}" ]
then
    printf 'Step 5: Server with GUI\n\n'
    printf 'Do you want to install a desktop environment? [y|n]: '
    if { IFS= read -r i; printf '%s' "${i}"; } | grep -E -q -e "$( (command -v 'locale' && locale yesexpr) || printf '^[jJyY].*')"
    then
        data_packages_vmhostgui='true'
        printf 'Ok, Going to install GNOME.\n'
    else
        data_packages_vmhostgui='false'
        printf 'OK, there will be no GUI.\n'
    fi
    printf '\n\n'
fi


# Write out KS commands for later include. Have a look above the corresponding
# %include lines for comments on the used kickstart commands itself.

# network.ks
printf '%s\n' "network --bootproto=dhcp --activate --hostname=${data_hostname}.${data_domainname}" > /tmp/network.ks
# ignoredisk.ks
printf '%s\n' "ignoredisk --only-use=${data_drive}" > /tmp/ignoredisk.ks
# bootloader.ks
printf '%s\n' "bootloader --append=\" crashkernel=auto \" --location=\"mbr\" --boot-drive=\"${data_drive}\"" > /tmp/bootloader.ks
# clearpart.ks
printf '%s\n' "clearpart --all --drives=${data_drive}" > /tmp/clearpart.ks
# part-boot.ks
printf '%s\n' "part /boot --fstype=\"xfs\" --ondisk=${data_drive} --size=768" > /tmp/part-boot.ks
# part-pv.ks
if [ -z "${data_dmcrypt_pwdplain}" ]
then
    printf '%s\n' "part pv.01 --fstype=\"lvmpv\" --ondisk=${data_drive} --grow" > /tmp/part-pv.ks
else
    printf '%s\n' "part pv.01 --fstype=\"lvmpv\" --ondisk=${data_drive} --grow --encrypted --passphrase=${data_dmcrypt_pwdplain}" > /tmp/part-pv.ks # writing the password into a file is OK here. /tmp is a volatile FS and only existing until after the intallation.
fi
# logvol.ks
if [ "$(printf '%d' $(cat '/proc/partitions' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -E -e "${data_drive}\$" | tr -s '[:space:]' ' ' | cut -d ' ' -f 3))" -gt 86769664 ] # all linux blocks are currently 1024 bytes (cf. manpage vmstat(8))
then
    # OS on different filesystem, more flexible, reduced risk of filled up root FS
    # 35840 + (5 x 10240) + 5120 + 2048 + 768 (boot) = 84736 MiB * 1024 = 86769664 bytes
    printf '%s\n' "$(cat <<-'DELIM'
	logvol /         --vgname=vg01 --name=os_root     --fstype="xfs"  --size=10240
	logvol /home     --vgname=vg01 --name=os_home     --fstype="xfs"  --size=2048
	logvol /var      --vgname=vg01 --name=os_var      --fstype="xfs"  --size=35840
	logvol /var/tmp  --vgname=vg01 --name=os_var_tmp  --fstype="xfs"  --size=10240
	logvol /var/log  --vgname=vg01 --name=os_var_log  --fstype="xfs"  --size=10240
	logvol /tmp      --vgname=vg01 --name=os_tmp      --fstype="xfs"  --size=10240
	logvol swap      --vgname=vg01 --name=os_swap     --fstype="swap" --size=5120
	DELIM
    )" > /tmp/logvol.ks
else
    # OS on single filesystem with at least 5 GiB, --grow as large as possible
    printf '%s\n' "$(cat <<-'DELIM'
	logvol /         --vgname=vg01 --name=os_root     --fstype="xfs"  --size=5120 --grow
	logvol swap      --vgname=vg01 --name=os_swap     --fstype="swap" --size=1024
	DELIM
    )" > /tmp/logvol.ks
fi
# packages.ks
printf '%s\n\n' '%packages' > /tmp/packages.ks # line not included in HEREDOC, otherwise %package makes Anaconda believe that the %pre section is not closed correctly
printf '%s\n' "$(cat <<-'DELIM'
### base
@^minimal
@core
@base
@hardware-monitoring
chrony
kexec-tools
rng-tools

### VM host (base)
@virtualization-hypervisor
@virtualization-tools
virt-install
virt-top
libguestfs-tools
DELIM
)" >> /tmp/packages.ks
if [ -n "${data_packages_vmhostgui}" ] &&
   [ "${data_packages_vmhostgui}" = "true" ]
then
    printf '%s\n' "$(cat <<-'DELIM'
	### VM host (GUI)
	@x11
	@gnome-desktop
	@fonts
	@input-methods
	@internet-browser
	virt-manager
	virt-viewer
	-cheese
	-empathy
	-totem
	-totem-nautilus
	-gnome-boxes
	-gnome-contacts
	-gnome-documents
	-gnome-video-effects
	# GNOME comes with unoconv which has LibreOffice as dependency
	-unoconv
	-@office-suite
	-libreoffice-core
	-libreoffice-calc
	-libreoffice-draw
	-libreoffice-impress
	-libreoffice-writer
	-libreoffice-opensymbol-fonts
	-libreoffice-ure
	DELIM
    )" >> /tmp/packages.ks
fi
printf '\n%s\n' '%end' >> /tmp/packages.ks


# Take care about potentially low available entropy.
#
# Opinions differ on what "low" is (maximum value is 4096 bits (=512 bytes)):
# - 2048 bits (=256 bytes)
# - 1024 bits (=128 bytes)
# - 256  bits (=32 bytes), usual lower limit for *seeding* (cf. bit.ly/2upceFv)
# One should keep in mind that "/proc/sys/kernel/random/entropy_avail" provides
# only an *estimation* (cf. bit.ly/2wbMCyf). Therefore we use 2048 bits here as
# our definition of "low".
#
# We handle this topic now as it is relevant for the following full disk
# encryption (even though Anaconda is also checking this in recent versions).
i='0'
entropy_avail="$(cat /proc/sys/kernel/random/entropy_avail)"
while [ "${entropy_avail}" -lt 2048 ]
do
    i="$((${i}+1))"
    printf '%s\n' "Warning: The available entropy (${entropy_avail}) is rather low. This loop will end" \
                  "         whether there is enough entropy or after "$((6-${i}))" remaining iterations." \
                  '         Checking again in 10s..."'
    sleep '10s'
    if [ "${i}" -ge 6 ]
    then
        break 1
    fi
    entropy_avail="$(cat /proc/sys/kernel/random/entropy_avail)"
done
unset i entropy_avail


# make /dev/tty1 the foreground terminal, switch back to it and redirect all
# input and output. The graphical interface (and therefore Anaconda) lives on
# /dev/tty1.
chvt 1
exec < /dev/tty1 > /dev/tty1 2> /dev/tty1

%end






###### Setup / Anaconda

# use graphical install
graphical

# X Window System configuration information
xconfig --startxonboot

# use CDROM installation media
# Note: this is also the option for USB keys and other none-network sources
cdrom

# accept license agreement
eula --agreed

# run the setup agent on first boot
firstboot --enable

# setup completion method / what to do after the installation was finished
#   [commented out, let user decide by using the UI Anaconda provides]:  reboot



###### Network

# Network information
%include /tmp/network.ks



###### Internationalization (I18N), Localization (L10N)



# Keyboard layouts
#
# Hints and notes:
# - Get list of supported keyboard layouts: localectl list-keymaps
keyboard 'us'

# System language
#
# Hints and notes:
# - Get list of supported system languages: localectl list-locales
#  [commented out, let user decide by using the UI Anaconda provides]:  lang de_DE.UTF-8

# System timezone
#
# Hints and notes:
# - Get list of supported timezones: timedatectl list-timezones
# - --utc = System assumes the hardware clock is set to UTC time.
#   FIXME doc states --utc, files created by Anaconda are using --isUtc;
#         Which one is correct? cf. https://bugs.centos.org/view.php?id=3631
#
#  [commented out, let user decide by using the UI Anaconda provides]:  timezone Europe/Berlin --isUtc
#   NOTE: "timezone" is also commented out for another reason. A lack ot it
#         prevents Anaconda from starting the installation automatically. This
#         enables the user to use the UI to adapt misc settings before the
#         installation happens. Might be useful from time to time, especially
#         regarding network settings.



###### Authentication

# system authorization information
auth --enableshadow --passalgo=sha512



###### Users and groups

# Snippet to create SHA512 crypt compatible user password hashes:
# python -c 'import crypt,getpass;pw=getpass.getpass();print(crypt.crypt(pw) if (pw==getpass.getpass("Confirm: ")) else exit())'


# user: root
# The root user does already exist at this point in time, therefore one has to
# use the dedicated "rootpw" command instead of "user --name=root".
#  [commented out, let user decide by using the UI Anaconda provides]:  rootpw --iscrypted --password=[SHA512 crypt password hash, see above for snippet to create one]

# user: user
#  [commented out, let user decide by using the UI Anaconda provides]:  user --name=user --gecos="User" --iscrypted --password=[SHA512 crypt password hash, see above for snippet to create one]



###### Disk setup, boot loader

# make sure we do not overwrite some expected device, use defined installation
# target in every case
%include /tmp/ignoredisk.ks

# zerombr initializes any **invalid** partition tables found on disks.
zerombr

# Install bootloader (GRUB2).
#
# Notes on the used parameters:
# --append
#   additional kernel parameters.
# --boot-drive
#   drive the boot loader should be written to.
# --location
#   Where the boot record is written. Value "mbr" leads to:
#     - On a GPT-formatted disk, install boot loader into the BIOS boot
#       partition.
#     - On an MBR-formatted disk, install boot loader into the empty space
#       between the MBR and the first partition.
%include /tmp/bootloader.ks



###### Partitioning

# Greenfield strategy: remove partitions from our installation target, prior
# to creation of new ones.
%include /tmp/clearpart.ks

# Create partitions required by the current hardware platform:
# - A /boot/efi partition for systems with UEFI firmware
# - A biosboot partition for systems with BIOS firmware and GPT (see
#   red.ht/2ucqmH1 and red.ht/2hv7o8K for more information)
#
# The inst.gpt boot parameter forces a GPT partition table even when the disk
# size is less than 2^32 sectors, cf. red.ht/2psiz5w. You want to set this in
# the syslinux config file.
reqpart

# Create boot partition as first partition on disk. Will be unencrypted in
# every case.
#
# Red Hat recommends at least 1 GiB (cf. red.ht/1EZNQYQ), we use less as
# we usually do not keep many old kernels or even no old ones because of
# security rules.
%include /tmp/part-boot.ks

# Create LVM Physical Volume (PV)
#
# Notes on the used parameters:
# - Partition name "pv.[id]" is the syntax used as mountpoint for LVM by "part".
# - --grow as large as possible (=all remaining free space on the disk or up to
#   the maximum size setting, if one is specified).
%include /tmp/part-pv.ks

# Create LVM Volume Group (VG).
# Physical Extend (PE) size is not defined, default is 4096 bytes. A very high
# number of PEs might slow down management tools but does NOT influence IO
# performance (cf. manpage vgcreate(8), -s param)
volgroup vg01 pv.01

# Create LVM Logical Volumes (LVs)
# - For logvol parameter description, see "RHEL 7 Installation Guide,
#   26.3.1. Kickstart Commands and Options" (cf. red.ht/1Dos5ED)
# - For LV naming rules, see manpage von lvm(8), "VALID NAMES" section.
# - On sizes: "RHEL 7 Installation Guide, 8.14.4.4. Recommended Partitioning
#   Scheme" (cf. red.ht/1EZNQYQ) provides general hints.
%include /tmp/logvol.ks


###### Services (modifies systemd target "default")

services --enabled="chronyd"



###### Packages
#
# Notes:
# - You can specify packages by environment, group, or by their package names.
# - Get details of the available packages groups:
#   yum grouplist ids hidden
#   yum groupinfo <id>
#     or
#   dnf -v grouplist
#   dnf grouplist hidden
#   dnf groupinfo <id>
# - See "RHEL 7 Installation Guide, 26.3.2. Package Selection" (cf.
#   red.ht/1ECqgSK) for more documentation
# - Syntax hints:
#     @^environment
#     @group
#     simple-package
#   Put a "-" in front for removal
%include /tmp/packages.ks



#### Kdump
# Disabled on this machine (as we do not have support for CentOS nor usually
# need this on a default system for debugging) - one might configure it later
# in /etc/kdump.conf if needed.
%addon com_redhat_kdump com_redhat_kdump --disable

%end



#### OpenSCAP
#%addon org_fedora_oscap

# OpenSCAP is not used here at the moment. We should change that ASAP as it
# really makes sense.

#%end



#### Anaconda
%anaconda

# password policy for root
pwpolicy root --minlen=10 --minquality=50 --strict --nochanges --notempty

# password policy for all non-root users
pwpolicy user --minlen=10 --minquality=50 --strict --nochanges --notempty

# password policy for dm-crypt/LUKS
# ATTENTION: One has to keep the %pre script stricter or in sync with the
#            following kickstart cmd (cf. regex_dmcryptpwd variable and pwscore
#            value when asking the user for a password).
pwpolicy luks --minlen=20 --minquality=50 --strict --nochanges --notempty

%end



#### Post-install scripts
#
# Notes:
# - For exchanging data between %pre and %post: cf. comments above %pre.
# - If really needed, "%post --nochroot" can be used to change things on the
#   freshly installed system.
# - RHEL 7 Installation Guide, 26.3.5. Post-installation Script, red.ht/1Q08cug

# %post
#   Nothing right now
# %end
