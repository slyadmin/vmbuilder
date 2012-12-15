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
  add_option_hypervisor_lxc

  function checkroot() { echo checkroot $*; }
  function shlog() { echo shlog $*; }
}

function test_lxc_destroy() {
  lxc_destroy vmbuilder
}

## shunit2

. ${shunit2_file}