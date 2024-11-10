#!/bin/sh
set -e

# Source the configuration file
CONFIG_FILE="rke2_config.sh"
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "[ERROR] Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Helper functions
info() { echo "[INFO] " "$@"; }
warn() { echo "[WARN] " "$@" >&2; }
fatal() { echo "[ERROR] " "$@" >&2; exit 1; }

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    fatal "You need to be root to perform this install"
fi

# Arch and OS setup
ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) ARCH=amd64; SUFFIX=$(uname -s | tr '[:upper:]' '[:lower:]')-${ARCH} ;;
    aarch64|arm64) ARCH=arm64; SUFFIX=$(uname -s | tr '[:upper:]' '[:lower:]')-${ARCH} ;;
    *) fatal "Unsupported architecture ${ARCH}";;
esac

# Set up local tarball paths
TMP_DIR=$(mktemp -d -t rke2-install.XXXXXXXXXX)
TMP_TARBALL="${TMP_DIR}/rke2.tarball"
TMP_CHECKSUMS="${TMP_DIR}/rke2.checksums"
TMP_AIRGAP_TARBALL="${TMP_DIR}/rke2-images.tarball"
trap "rm -rf ${TMP_DIR}" EXIT

# Check if tarball exists locally, else download it
if [ ! -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2.${SUFFIX}.tar.gz" ]; then
    info "Local tarball not found, downloading from ${RKE2_TARBALL_URL}"
    curl -L -o "${TMP_TARBALL}" "${RKE2_TARBALL_URL}"
else
    cp -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2.${SUFFIX}.tar.gz" "${TMP_TARBALL}"
fi

# Verify and unpack the tarball
info "Verifying and unpacking tarball..."
CHECKSUM_EXPECTED=$(grep "rke2.${SUFFIX}.tar.gz" "${INSTALL_RKE2_ARTIFACT_PATH}/sha256sum-${ARCH}.txt" | awk '{print $1}')
CHECKSUM_ACTUAL=$(sha256sum "${TMP_TARBALL}" | awk '{print $1}')
if [ "${CHECKSUM_EXPECTED}" != "${CHECKSUM_ACTUAL}" ]; then
    fatal "Checksum mismatch for main tarball"
fi

tar xzf "${TMP_TARBALL}" -C "${INSTALL_RKE2_TAR_PREFIX}"
info "RKE2 installation complete"
exit 0
