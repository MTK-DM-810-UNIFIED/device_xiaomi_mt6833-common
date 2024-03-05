#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
	echo "Unable to find helper script at ${HELPER}"
	exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
	case "${1}" in
		--only-common )
			ONLY_COMMON=true
			;;
		--only-target )
			ONLY_TARGET=true
			;;
		-n | --no-cleanup )
			CLEAN_VENDOR=false
			;;
		-k | --kang )
			KANG="--kang"
			;;
		-s | --section )
			SECTION="${2}"; shift
			CLEAN_VENDOR=false
			;;
		* )
			SRC="${1}"
			;;
	esac
	shift
done

if [ -z "${SRC}" ]; then
	SRC="adb"
fi

symlink_fixup(){
	[ "${SRC}" != "adb" ] && {
		local dir="$(dirname ${SRC}/${1})"
		local fname="$(basename ${SRC}/${1})"
		local plat="$(grep 'ro.board.platform' ${SRC}/vendor/build.prop | cut -d= -f2 | head -1)"
		local fpath="${dir}/${plat}/${fname}"
		[ -f "${fpath}" ] && {
			rm -rf "${2}"
			cp -f "${fpath}" "${2}"
		}
	}
}
export -f symlink_fixup

function blob_fixup {
	case "$1" in
		vendor/bin/mnld | vendor/lib*/libaalservice.so | vendor/lib*/libcam.utils.sensorprovider.so)
			grep -q "libsensorndkbridge.so" "${2}" && \
			"${PATCHELF}" --replace-needed "libsensorndkbridge.so" "libsensorndkbridge-hidl.so" "${2}"
			;;
		vendor/etc/init/android.hardware.neuralnetworks@1.3-service-mtk-neuron.rc)
			sed -i 's/start/enable/' "${2}"
			;;
		vendor/etc/init/vendor.mediatek.hardware.mtkpower@1.0-service.rc)
			echo "$(cat ${2}) input" > "${2}"
			;;
		vendor/etc/vintf/manifest/manifest_media_c2_V1_2_default.xml)
			sed -i 's/1.1/1.2/' "$2"
			;;
		vendor/lib*/libaiselector.so | vendor/lib*/libdpframework.so | vendor/lib*/libmtk_drvb.so | \
		vendor/lib*/libnir_neon_driver.so | vendor/lib*/libpq_prot.so)
			symlink_fixup "${1}" "${2}"
			;;
	esac
}
if [ -z "${ONLY_TARGET}" ]; then
	# Initialize the helper for common device
	setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON:-$VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

	extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" ]; then
	# Reinitialize the helper for device
	source "${MY_DIR}/../../${VENDOR}/${DEVICE}/extract-files.sh"
	setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

	extract "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
