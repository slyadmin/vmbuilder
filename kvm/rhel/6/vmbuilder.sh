#!/bin/bash
#
# <based on vmbuilder>
#
# NAME
#        vmbuilder - builds virtual machines from the command line
#
# SYNOPSIS
#        vmbuilder <hypervisor> <distro> [OPTIONS]...
#
#        <hypervisor>  Hypervisor image format. Valid options: xen kvm vmw6 vmserver
#
#        <distro>      Distribution. Valid options: ubuntu
#
# OPTIONS
#
#    Guest partitioning options
#
#        The following three options are not used if --part is specified:
#
#               --rootsize SIZE
#                      Size (in MB) of the root filesystem [default: 4096].  Discarded when --part is used.
#
#               --optsize SIZE
#                      Size (in MB) of the /opt filesystem. If not set, no /opt filesystem will be added. Discarded when --part is used.
#
#               --swapsize SIZE
#                      Size (in MB) of the swap partition [default: 1024]. Discarded when --part is used.
#
#
#    Post install actions:
#        --copy FILE
#               Read 'source dest' lines from FILE, copying source files from host to dest in the guest's file system.
#
#        --execscript SCRIPT, --exec SCRIPT
#               Run SCRIPT after distro installation finishes. Script will be called with the guest's chroot as first argument, so you can use chroot $1 <cmd> to  run  code  in
#               the virtual machine.
#
#
#
set -e

args=
while [ $# -gt 0 ]; do
  arg="$1"
  case "${arg}" in
    --*=*)
      key=${arg%%=*}; key=${key##--}
      value=${arg##--*=}
      eval "${key}=\"${value}\""
      ;;
    *)
      args="${args} ${arg}"
      ;;
  esac
  shift
done

#
debug=${debug:-}
[ -z ${debug} ] || set -x

#
distro_name=${distro_name:-centos}
distro_ver=${distro_ver:-6}
distro_arch=${distro_arch:-x86_64}
distro=${distro_name}-${distro_ver}_${distro_arch}
distro_dir=${distro_dir:-${distro}}

[ -d ${distro_dir} ] || {
  printf "[INFO] Building OS tree: %s\n" ${distro_dir}
  ./build-rootfs-tree.sh --distro_name=${distro_name} --distro_ver=${distro_ver} --distro_arch=${distro_arch} --batch=1
}


# * /usr/share/pyshared/VMBuilder/contrib/cli.py

#
# OptionGroup('Disk')
# -------------------
#
# + ('--rootsize', metavar='SIZE', default=4096, help='Size (in MB) of the root filesystem [default: %default]')
# + ('--swapsize', metavar='SIZE', default=1024, help='Size (in MB) of the swap partition [default: %default]')
# + ('--raw', metavar='PATH', type='str', help="Specify a file (or block device) to as first disk image.")
#
rootsize=${rootsize:-2048}
swapsize=${swapsize:-512}
execscript=${execscript:-./execscript.sh}
raw=${raw:-./${distro}.raw}

# local params
disk_filename=${raw}
size=$((${rootsize=2048} + ${swapsize=512}))

# * /usr/share/pyshared/VMBuilder/disk.py
# rhel)
qemu_img_path=qemu-img
# ubuntu|debian)
# qemu_img_path=kvm-img


# def create(self):
printf "[INFO] Creating disk image: \"%s\" of size: %dMB\n" ${disk_filename} ${size}
${qemu_img_path} create -f raw ${disk_filename} ${size}M

# def partition(self)
printf "[INFO] Adding partition table to disk image: %s\n" ${disk_filename}
parted --script    ${disk_filename} mklabel msdos

printf "[INFO] Adding type %s partition to disk image: %s\n" ext2 ${disk_filename}
parted --script -- ${disk_filename} mkpart  primary ext2 0 $((${rootsize} - 1))
printf "[INFO] Adding type %s partition to disk image: %s\n" swap ${disk_filename}
parted --script -- ${disk_filename} mkpart  primary 'linux-swap(new)' ${rootsize} $((${size} - 1))

# def map_partitions(self):
#        mapdevs = []
#        for line in parts:
#            mapdevs.append(line.split(' ')[2])
printf "[INFO] Creating loop devices corresponding to the created partitions\n"
mapdevs=$(
 kpartx -va ${disk_filename} \
  | egrep -v "^(gpt|dos):" \
  | egrep -w add \
  | while read line; do
      echo ${line} | awk '{print $3}'
    done
)
#        for (part, mapdev) in zip(self.partitions, mapdevs):
#            part.set_filename('/dev/mapper/%s' % mapdev)
part_filenames=$(
  for mapdev in ${mapdevs}; do
    echo /dev/mapper/${mapdev}
  done
)

#    def mkfs(self):
#        if not self.filename:
#            raise VMBuilderException('We can\'t mkfs if filename is not set. Did you forget to call .create()?')
#        if not self.dummy:
#            cmd = self.mkfs_fstype() + [self.filename]
#            run_cmd(*cmd)
#            # Let udev have a chance to extract the UUID for us
#            run_cmd('udevadm', 'settle')
#            if os.path.exists("/sbin/vol_id"):
#                self.uuid = run_cmd('vol_id', '--uuid', self.filename).rstrip()
#            elif os.path.exists("/sbin/blkid"):
#                self.uuid = run_cmd('blkid', '-c', '/dev/null', '-sUUID', '-ovalue', self.filename).rstrip()

getid_path=
[ -x /sbin/vol_id ] && getid_path=/sbin/vol_id || :
[ -x /sbin/blkid  ] && getid_path=/sbin/blkid  || :

uuids=
for part_filename in ${part_filenames}; do
  case ${part_filename} in
  *p1)
    mkfs.ext4 -F ${part_filename}
    ;;
  *p2)
    mkswap ${part_filename}
    ;;
  *)
    ;;
  esac
  udevadm settle
  case ${getid_path} in
  /sbin/vol_id)
    uuid=$(${getid_path} --uuid ${part_filename})
    ;;
  /sbin/blkid)
    uuid=$(${getid_path} -c /dev/null -sUUID -ovalue ${part_filename})
    ;;
  esac

  uuids="${uuids} ${uuid}"
done


#    def mount(self, rootmnt):
#        if (self.type != TYPE_SWAP) and not self.dummy:
#            logging.debug('Mounting %s', self.mntpnt)
#            self.mntpath = '%s%s' % (rootmnt, self.mntpnt)
#            if not os.path.exists(self.mntpath):
#                os.makedirs(self.mntpath)
#            run_cmd('mount', '-o', 'loop', self.filename, self.mntpath)
#            self.vm.add_clean_cb(self.umount)

mntpnt=/tmp/tmp$(date +%s)
[ -d ${mntpnt} ] && { exit 1; } || mkdir -p ${mntpnt}

for part_filename in ${part_filenames}; do
  case ${part_filename} in
  *p1)
    printf "[DEBUG] Mounting %s\n" ${mntpnt}
    mount -o loop ${part_filename} ${mntpnt}
    ;;
  esac
done

#    def install_os(self):
#        self.nics = [self.NIC()]
#        self.call_hooks('preflight_check')
#        self.call_hooks('configure_networking', self.nics)
#        self.call_hooks('configure_mounting', self.disks, self.filesystems)
#
#        self.chroot_dir = tmpdir()
#        self.call_hooks('mount_partitions', self.chroot_dir)
#        run_cmd('rsync', '-aHA', '%s/' % self.distro.chroot_dir, self.chroot_dir)
#distro=centos-6_x86_64
#distro_dir=./${distro}

[ -d ${distro_dir} ] || { echo "no such directory: ${distro_dir}" >&2; exit 1; }

printf "[DEBUG] Installing OS to %s\n" ${mntpnt}
rsync -aHA ${distro_dir}/ ${mntpnt}
sync

#        if self.needs_bootloader:
#            self.call_hooks('install_bootloader', self.chroot_dir, self.disks)
#        self.call_hooks('install_kernel', self.chroot_dir)
#        self.call_hooks('unmount_partitions')
#        os.rmdir(self.chroot_dir)



# * /usr/share/pyshared/VMBuilder/plugins/ubuntu/distro.py
#    def install_bootloader(self, chroot_dir, disks):
chroot_dir=${mntpnt}

#        root_dev = VMBuilder.disk.bootpart(disks).get_grub_id()

#
#        tmpdir = '/tmp/vmbuilder-grub'
#        os.makedirs('%s%s' % (chroot_dir, tmpdir))
tmpdir=/tmp/vmbuilder-grub
mkdir -p ${chroot_dir}/${tmpdir}

#        self.context.add_clean_cb(self.install_bootloader_cleanup)
#        devmapfile = os.path.join(tmpdir, 'device.map')
#        devmap = open('%s%s' % (chroot_dir, devmapfile), 'w')
devmapfile=${tmpdir}/device.map
touch ${chroot_dir}/${devmapfile}

#        for (disk, id) in zip(disks, range(len(disks))):
grub_id=0

#            new_filename = os.path.join(tmpdir, os.path.basename(disk.filename))
#            open('%s%s' % (chroot_dir, new_filename), 'w').close()
#            run_cmd('mount', '--bind', disk.filename, '%s%s' % (chroot_dir, new_filename))
new_filename=${tmpdir}/$(basename ${disk_filename})
touch ${chroot_dir}/${new_filename}
mount --bind ${disk_filename} ${chroot_dir}/${new_filename}

#            st = os.stat(disk.filename)
#            if stat.S_ISBLK(st.st_mode):
#                for (part, part_id) in zip(disk.partitions, range(len(disk.partitions))):
#                    part_mountpnt = '%s%s%d' % (chroot_dir, new_filename, part_id+1)
#                    open(part_mountpnt, 'w').close()
#                    run_cmd('mount', '--bind', part.filename, part_mountpnt)
#            devmap.write("(hd%d) %s\n" % (id, new_filename))
printf "(hd%d) %s\n" ${grub_id} ${new_filename} >> ${chroot_dir}/${devmapfile}

#        devmap.close()
#        run_cmd('cat', '%s%s' % (chroot_dir, devmapfile))
cat ${chroot_dir}/${devmapfile}

#        self.suite.install_grub(chroot_dir)
#        self.run_in_target('grub', '--device-map=%s' % devmapfile, '--batch',  stdin='''root %s
#setup (hd0)
#EOT''' % root_dev)

cat <<_EOS_ | chroot ${chroot_dir} grub --device-map=${devmapfile} --batch
root (hd${grub_id},0)
setup (hd0)
quit
_EOS_

#
rootdev_uuid=$(echo ${uuids} | awk '{print $1}')
swapdev_uuid=$(echo ${uuids} | awk '{print $2}')

# /boot/grub/grub.conf
printf "[INFO] Generating /boot/grub/grub.conf.\n"
cat <<_EOS_ > ${chroot_dir}/boot/grub/grub.conf
default=0
timeout=5
splashimage=(hd${grub_id},0)/boot/grub/splash.xpm.gz
hiddenmenu
title ${distro} ($(cd ${chroot_dir}/boot && ls vmlinuz-* | tail -1 | sed 's,^vmlinuz-,,'))
        root (hd${grub_id},0)
        kernel /boot/$(cd ${chroot_dir}/boot && ls vmlinuz-* | tail -1) ro root=UUID=${rootdev_uuid} rd_NO_LUKS rd_NO_LVM LANG=en_US.UTF-8 rd_NO_MD quiet SYSFONT=latarcyrheb-sun16 rhgb crashkernel=auto  KEYBOARDTYPE=pc KEYTABLE=us rd_NO_DM
        initrd /boot/$(cd ${chroot_dir}/boot && ls initramfs-*| tail -1)
_EOS_
cat ${chroot_dir}/boot/grub/grub.conf
chroot ${chroot_dir} ln -s /boot/grub/grub.conf /boot/grub/menu.lst

# /etc/fstab
printf "[INFO] Overwriting /etc/fstab.\n"
cat <<_EOS_ > ${chroot_dir}/etc/fstab
UUID=${rootdev_uuid} /                       ext4    defaults        1 1
UUID=${swapdev_uuid} swap                    swap    defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
_EOS_
cat ${chroot_dir}/etc/fstab

# disable mac address caching
printf "[INFO] Unsetting udev 70-persistent-net.rules.\n"
rm -f ${chroot_dir}/etc/udev/rules.d/70-persistent-net.rules
ln -s /dev/null ${chroot_dir}/etc/udev/rules.d/70-persistent-net.rules

[ -f ${chroot_dir} ] || {
  cat <<EOS > ${execscript}
#!/bin/bash

set -e

echo "doing execscript.sh: \$1"
chroot \$1 bash -c "echo root:root | chpasswd"
EOS
  chmod 755 ${execscript}
}

[ -x ${execscript} ] && {
  printf "[INFO] Excecuting after script\n"
  ${execscript} ${chroot_dir}
}

printf "[DEBUG] Unmounting %s\n" ${chroot_dir}/${new_filename}
umount ${chroot_dir}/${new_filename}

printf "[DEBUG] Unmounting %s\n" ${mntpnt}
umount ${mntpnt}

printf "[INFO] Deleting loop devices\n"

tries=0
max_tries=3
while [ ${tries} -lt ${max_tries} ]; do
  kpartx -vd ${disk_filename} && break || :
  tries=$(({tries} + 1))
  sleep 1
  [ ${tries} -ge ${max_tries} ] && printf "[INFO] Could not unmount '%s' after '%d' attempts. Final attempt" ${disk_filename} ${tries}
done
kpartx -vd ${disk_filename} || :

rmdir ${mntpnt}

printf "[INFO] Generated => %s\n" ${disk_filename}
printf "[INFO] Complete!\n"