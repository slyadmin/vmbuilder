# -*-Shell-script-*-
#
# description:
#  Linux Distribution
#
# requires:
#  bash
#
# imports:
#  distro: load_distro_driver
#

function add_option_distro_fedora18() {
  load_distro_driver fedora17

  gpgkey=https://fedoraproject.org/static/DE7F38BD.txt
}
