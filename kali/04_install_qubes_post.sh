#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

## Adapated from Whonix template
## See https://github.com/Whonix/qubes-template-whonix

## If .prepared_debootstrap has not been completed, don't continue.
exitOnNoFile "${INSTALLDIR}/${TMPDIR}/.prepared_qubes" "prepared_qubes installation has not completed!... Exiting"

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

mount --bind /dev "${INSTALLDIR}/dev"

aptInstall apt-transport-https
aptInstall apt-transport-tor

installQubesRepo

## Debugging.
env

[ -n "$kali_repository_uri" ] || kali_repository_uri="http://http.kali.org/kali"

## Better to build from buster-proposed-updates to test the upgrades.
[ -n "$kali_repository_suite" ] || kali_repository_suite="kali-rolling"
[ -n "$kali_signing_key_fingerprint" ] || kali_signing_key_fingerprint="44C6513A8E4FB3D30875F758ED444FF07D8D0BF6"
[ -n "$kali_signing_key_file" ] || kali_signing_key_file="$BUILDER_DIR/$SRC_DIR/template-kali/keys/kali-key.asc"
[ -n "$gpg_keyserver" ] || gpg_keyserver="keys.gnupg.net"
[ -n "$kali_repository_components" ] || kali_repository_components="main non-free contrib"
[ -n "$kali_repository_apt_line" ] || kali_repository_apt_line="deb $kali_repository_uri $kali_repository_suite $kali_repository_components"
[ -n "$kali_repository_apt_sources_list" ] || kali_repository_apt_sources_list="/etc/apt/sources.list.d/kali.list"
[ -n "$apt_target_key" ] || apt_target_key="/etc/apt/trusted.gpg.d/kali.gpg"

kali_signing_key_file_name="$(basename "$kali_signing_key_file")"

## Debugging.
test -f "$kali_signing_key_file"

cp "$kali_signing_key_file" "${INSTALLDIR}/${TMPDIR}/${kali_signing_key_file_name}"

## Debugging.
$chroot_cmd test -f "${TMPDIR}/${kali_signing_key_file_name}"

$chroot_cmd apt-key --keyring "$apt_target_key" add "${TMPDIR}/${kali_signing_key_file_name}"

## Sanity test. apt-key adv would exit non-zero if not exactly that fingerprint in apt's keyring.
$chroot_cmd apt-key --keyring "$apt_target_key" adv --fingerprint "$kali_signing_key_fingerprint"

echo "$kali_repository_apt_line" > "${INSTALLDIR}/$kali_repository_apt_sources_list"

aptUpdate

if [ "${TEMPLATE_FLAVOR}" = "kali" ]; then
   aptInstall kali-linux-full
elif [ "${TEMPLATE_FLAVOR}" = "kali-all" ]; then
   aptInstall kali-linux-all
else
   error "TEMPLATE_FLAVOR is neither kali nor kali-all, it is: ${TEMPLATE_FLAVOR}"
fi

uninstallQubesRepo

## Workaround for Qubes bug:
## 'Debian Template: rely on existing tool for base image creation'
## https://github.com/QubesOS/qubes-issues/issues/1055
updateLocale

## Workaround. ntpdate needs to be removed here, because it can not be removed from
## template_debian/packages_qubes.list, because that would break minimal Debian templates.
## https://github.com/QubesOS/qubes-issues/issues/1102
UWT_DEV_PASSTHROUGH="1" aptRemove ntpdate || true

UWT_DEV_PASSTHROUGH="1" \
   DEBIAN_FRONTEND="noninteractive" \
   DEBIAN_PRIORITY="critical" \
   DEBCONF_NOWARNINGS="yes" \
      $chroot_cmd apt-get ${APT_GET_OPTIONS} autoremove

## Cleanup.
umount_all "${INSTALLDIR}/" || true
trap - ERR EXIT
trap
