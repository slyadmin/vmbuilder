#!/bin/bash
#
# requires:
#   bash
#

## include files

. ./helper_shunit2.sh

## variables

## public functions

function setUp() {
  mkdir -p ${chroot_dir}

  function chroot() { echo chroot $*; }
  function run_yum() { echo run_yum $*; }
}

function tearDown() {
  rm -rf ${chroot_dir}
}

function test_install_vzutils() {
  install_vzutils ${chroot_dir} | egrep 'vzctl vzquota'
  assertEquals $? 0
}

## shunit2

. ${shunit2_file}
