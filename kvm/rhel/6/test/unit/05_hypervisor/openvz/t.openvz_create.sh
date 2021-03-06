#!/bin/bash
#
# requires:
#   bash
#

## include files

. $(cd ${BASH_SOURCE[0]%/*} && pwd)/helper_shunit2.sh

## variables

declare chroot_dir=${abs_dirname}/chroot_dir.$$
declare vzconf_path=${chroot_dir}/etc/vz/vz.conf
declare vzconf_dir=${chroot_dir}/etc/vz/conf

## public functions

function setUp() {
  add_option_hypervisor_openvz

  mkdir -p ${vzconf_dir}
  cat <<-EOS > ${vzconf_path}
	## Defaults for containers
	VE_ROOT=${chroot_dir}/vz/root/\$VEID
	VE_PRIVATE=${chroot_dir}/vz/private/\$VEID
	EOS

  function checkroot() { :; }
  function next_ctid() { echo 102; }
  function shlog() { echo $*; }
}

function tearDown() {
  rm -rf ${chroot_dir}
}

function test_openvz_create() {
  local name=vmbuilder ctid=$(next_ctid)

  openvz_create ${name} | egrep -q -w "vzctl set ${ctid} --name ${name} --save"
  openvz_create ${name} | egrep -q -w "vzctl set ${ctid} --cpus 1 --save"
}

## shunit2

. ${shunit2_file}
