#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

#
# Handle legacy builder
#

if [ -z "${FLAVORS_DIR}" ]; then
    FLAVORS_DIR="${BUILDER_DIR}/${SRC_DIR}/template-kali"
fi

if [ -n "${SCRIPTSDIR}" ]; then
    TEMPLATE_CONTENT_DIR="${SCRIPTSDIR}"
fi

if [ -n "${INSTALLDIR}" ]; then
    INSTALL_DIR="${INSTALLDIR}"
fi

source "${TEMPLATE_CONTENT_DIR}/vars.sh"
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

## Adapated from Whonix template
## See https://github.com/Whonix/qubes-template-whonix

## If .prepared_debootstrap has not been completed, don't continue.
exitOnNoFile "${INSTALL_DIR}/${TMPDIR}/.prepared_qubes" "prepared_qubes installation has not completed!... Exiting"

#### '--------------------------------------------------------------------------
info ' Trap ERR and EXIT signals and cleanup (umount)'
#### '--------------------------------------------------------------------------
trap cleanup ERR
trap cleanup EXIT

prepareChroot

if [ "$(type -t chroot_cmd)" = "function" ]; then
    chroot_cmd="chroot_cmd"
else
    chroot_cmd="chroot"
fi

mount --bind /dev "${INSTALL_DIR}/dev"

aptInstall apt-transport-https
aptInstall apt-transport-tor

installQubesRepo

## Debugging.
env

[ -n "$kali_repository_uri" ] || kali_repository_uri="http://http.kali.org/kali"
[ -n "$kali_repository_suite" ] || kali_repository_suite="kali-rolling"
[ -n "$kali_signing_key_file" ] || kali_signing_key_file="${FLAVORS_DIR}/keys/kali-archive-keyring.gpg"
[ -n "$kali_repository_components" ] || kali_repository_components="main non-free contrib"
[ -n "$kali_repository_apt_line" ] || kali_repository_apt_line="deb $kali_repository_uri $kali_repository_suite $kali_repository_components"
[ -n "$kali_repository_apt_sources_list" ] || kali_repository_apt_sources_list="/etc/apt/sources.list.d/kali.list"
[ -n "$apt_target_key" ] || apt_target_key="/etc/apt/trusted.gpg.d/kali-archive-keyring.gpg"

kali_signing_key_file_name="$(basename "$kali_signing_key_file")"

test -f "$kali_signing_key_file"
cp "$kali_signing_key_file" "${INSTALL_DIR}/${apt_target_key}"

echo "$kali_repository_apt_line" > "${INSTALL_DIR}/$kali_repository_apt_sources_list"

## We restore previous state of grub-pc because
## upgrade fails due to /dev/xvda.
# find the right loop device, _not_ its partition
dev=$(df --output=source ${INSTALL_DIR} | tail -n 1)
dev=${dev%p?}
echo "grub-pc grub-pc/install_devices multiselect $dev" | chroot_cmd debconf-set-selections

aptUpdate
aptDistUpgrade

## Allow downgrading versions (e.g. minor python3 deps are not satisfied)
cat > "${INSTALL_DIR}/etc/apt/preferences.d/allow-downgrade" << EOF
Package: *
Pin: release o=Kali
Pin-Priority: 1001
EOF

KALI_PACKAGES=kali-menu
if [ "${TEMPLATE_FLAVOR}" = "kali" ]; then
    KALI_PACKAGES="$KALI_PACKAGES kali-linux-default"
elif [ "${TEMPLATE_FLAVOR}" = "kali-core" ]; then
    KALI_PACKAGES="$KALI_PACKAGES kali-linux-core"
elif [ "${TEMPLATE_FLAVOR}" = "kali-large" ]; then
    KALI_PACKAGES="$KALI_PACKAGES kali-linux-large"
elif [ "${TEMPLATE_FLAVOR}" = "kali-everything" ]; then
    KALI_PACKAGES="$KALI_PACKAGES kali-linux-everything"
else
    error "TEMPLATE_FLAVOR must be kali, kali-core, kali-large or kali-everything. Selected: ${TEMPLATE_FLAVOR}"
fi

aptInstall --allow-downgrades $KALI_PACKAGES

uninstallQubesRepo

updateLocale

UWT_DEV_PASSTHROUGH="1" DEBIAN_FRONTEND="noninteractive" DEBIAN_PRIORITY="critical" DEBCONF_NOWARNINGS="yes" \
    $chroot_cmd $eatmydata_maybe apt-get "${APT_GET_OPTIONS[@]}" autoremove

## We reapply the modification for grub-pc
echo "grub-pc grub-pc/install_devices multiselect /dev/xvda" | chroot_cmd debconf-set-selections
chroot_cmd update-grub2

## Cleanup.
umount_all "${INSTALL_DIR}/" || true
trap - ERR EXIT
trap
