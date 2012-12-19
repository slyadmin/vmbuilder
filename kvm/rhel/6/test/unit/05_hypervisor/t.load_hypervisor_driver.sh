#!/bin/bash
#
# requires:
#   bash
#

## include files

. $(cd $(dirname ${BASH_SOURCE[0]}) && pwd)/helper_shunit2.sh

## variables

## public functions

function test_load_hypervisor_driver_no_opts() {
  load_hypervisor_driver
  assertNotEquals $? 0
}

function test_load_hypervisor_driver_kvm() {
  load_hypervisor_driver kvm
  assertEquals $? 0
}

function test_load_hypervisor_driver_unknown() {
  load_hypervisor_driver unknown
  assertNotEquals $? 0
}


## shunit2

. ${shunit2_file}
