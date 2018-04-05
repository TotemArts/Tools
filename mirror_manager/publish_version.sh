#!/bin/bash
#
# To use this script, define $version_data_destination below.
# You must also be setup for non-interactive authentication with the user/host
#

# Configuration variables
# $version_data_destination = user@host:dir/

# Setup some vars
json=${bin}version/*.json
args='-av --update'

# Connect and transfer over the version files
rsync $args $json $version_data_destination
