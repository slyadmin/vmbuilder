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

  function run_in_target() { echo run_in_target $*; }
}

function tearDown() {
  rm -rf ${chroot_dir}
}

function test_install_epel_empty() {
  install_epel ${chroot_dir}
  assertEquals $? 0
}

function test_install_epel_defined() {
  local epel_uri=http://ftp.jaist.ac.jp/pub/Linux/Fedora/epel/6/i386/epel-release-6-7.noarch.rpm
  install_epel ${chroot_dir}
  assertEquals $? 0
}

## shunit2

. ${shunit2_file}