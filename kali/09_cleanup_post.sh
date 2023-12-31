#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 ] || [ "$DEBUG" == "1" ]; then
    set -x
fi

#
# Handle legacy builder
#

if [ -n "${SCRIPTSDIR}" ]; then
    TEMPLATE_CONTENT_DIR="${SCRIPTSDIR}"
fi

if [ -n "${INSTALLDIR}" ]; then
    INSTALL_DIR="${INSTALLDIR}"
fi

source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug ' Kali post installation cleanup'
##### '-------------------------------------------------------------------------
