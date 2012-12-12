#!/bin/bash
#
# requires:
#   bash
#

## include files

. ./helper_shunit2.sh

## variables

### re-initialize variables for this unit test


## public functions

function test_sum_disksize() {
  local rootsize=1024
  local swapsize=1024
  local optsize=1024

  assertEquals $(sum_disksize) $((${rootsize} + ${swapsize} + ${optsize}))
}

## shunit2

. ${shunit2_file}
