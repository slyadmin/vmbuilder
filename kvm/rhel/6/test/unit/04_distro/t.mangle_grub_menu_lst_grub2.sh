#!/bin/bash
#
# requires:
#   bash
#

## include files

. $(cd $(dirname ${BASH_SOURCE[0]}) && pwd)/helper_shunit2.sh

## variables

declare rootdev_uuid=ASDF-QWER-ZXCV

## public functions

function show_grub2_cfg() {
  cat <<'EOS'
#
# DO NOT EDIT THIS FILE
#
# It is automatically generated by grub2-mkconfig using templates
# from /etc/grub.d and settings from /etc/default/grub
#

### BEGIN /etc/grub.d/00_header ###
if [ -s $prefix/grubenv ]; then
  load_env
fi
set default="0"
if [ "${prev_saved_entry}" ]; then
  set saved_entry="${prev_saved_entry}"
  save_env saved_entry
  set prev_saved_entry=
  save_env prev_saved_entry
  set boot_once=true
fi

function savedefault {
  if [ -z "${boot_once}" ]; then
    saved_entry="${chosen}"
    save_env saved_entry
  fi
}

function load_video {
  insmod vbe
  insmod vga
  insmod video_bochs
  insmod video_cirrus
}

set timeout=5
### END /etc/grub.d/00_header ###

### BEGIN /etc/grub.d/10_linux ###
menuentry 'Linux, with Linux 3.1.0-7.fc16.x86_64' --class gnu-linux --class gnu --class os {
        load_video
        set gfxpayload=keep
        insmod gzio
        insmod part_msdos
        insmod ext2
        set root='(/dev/loop0,msdos1)'
        search --no-floppy --fs-uuid --set=root 8ded5d32-1c25-4680-bc66-e192de2ade42
        echo    'Loading Linux 3.1.0-7.fc16.x86_64 ...'
        linux   /boot/vmlinuz-3.1.0-7.fc16.x86_64 root=/dev/mapper/loop0p1 ro quiet rhgb
        echo    'Loading initial ramdisk ...'
        initrd  /boot/initramfs-3.1.0-7.fc16.x86_64.img
}
menuentry 'Linux, with Linux 3.1.0-7.fc16.x86_64 (recovery mode)' --class gnu-linux --class gnu --class os {
        load_video
        set gfxpayload=keep
        insmod gzio
        insmod part_msdos
        insmod ext2
        set root='(/dev/loop0,msdos1)'
        search --no-floppy --fs-uuid --set=root 8ded5d32-1c25-4680-bc66-e192de2ade42
        echo    'Loading Linux 3.1.0-7.fc16.x86_64 ...'
        linux   /boot/vmlinuz-3.1.0-7.fc16.x86_64 root=/dev/mapper/loop0p1 ro single quiet rhgb
        echo    'Loading initial ramdisk ...'
        initrd  /boot/initramfs-3.1.0-7.fc16.x86_64.img
}
### END /etc/grub.d/10_linux ###

### BEGIN /etc/grub.d/20_linux_xen ###
### END /etc/grub.d/20_linux_xen ###

### BEGIN /etc/grub.d/30_os-prober ###
### END /etc/grub.d/30_os-prober ###

### BEGIN /etc/grub.d/40_custom ###
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
### END /etc/grub.d/40_custom ###

### BEGIN /etc/grub.d/41_custom ###
if [ -f  $prefix/custom.cfg ]; then
  source $prefix/custom.cfg;
fi
### END /etc/grub.d/41_custom ###

### BEGIN /etc/grub.d/90_persistent ###
### END /etc/grub.d/90_persistent ###
EOS
}

function setUp() {
  mkdisk ${disk_filename} $(sum_disksize)
  mkdir -p ${chroot_dir}/boot/grub2

  function mntpntuuid() { echo ${rootdev_uuid}; }
  show_grub2_cfg > ${chroot_dir}/boot/grub2/grub.cfg
}

function tearDown() {
  rm -f ${disk_filename}
  rm -rf ${chroot_dir}
}

function test_mangle_grub_menu_lst_grub2() {
  local preferred_grub=grub

  mangle_grub_menu_lst_grub2 ${chroot_dir} ${disk_filename}

  egrep -q "set root='\(hd0,0\)'"      ${chroot_dir}/boot/grub2/grub.cfg
  assertEquals $? 0

  egrep -q "root=UUID=${rootdev_uuid}" ${chroot_dir}/boot/grub2/grub.cfg
  assertEquals $? 0

  egrep linux ${chroot_dir}/boot/grub2/grub.cfg | egrep -q -w 'quiet rhgb'
  assertNotEquals $? 0
}

## shunit2

. ${shunit2_file}
