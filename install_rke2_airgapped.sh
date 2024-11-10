#!/bin/sh
set -e

# Source the configuration file
CONFIG_FILE="rke2_config.sh"  # Set path to your config file if different

# Check if the configuration file exists
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
TMP_AIRGAP_TARBALL="${TMP_DIR}/rke2-images.tarball"
TMP_CHECKSUMS="${TMP_DIR}/rke2.checksums"
TMP_AIRGAP_CHECKSUMS="${TMP_DIR}/rke2-images.checksums"

# Function to clean up temp files on exit
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

# Staging and verification functions
info "Staging local files for air-gapped installation"

# Copy necessary files from the specified artifact path
cp -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2.${SUFFIX}.tar.gz" "${TMP_TARBALL}"
cp -f "${INSTALL_RKE2_ARTIFACT_PATH}/sha256sum-${ARCH}.txt" "${TMP_CHECKSUMS}"
cp -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2-images.${SUFFIX}.tar.gz" "${TMP_AIRGAP_TARBALL}"

# Verify tarball
CHECKSUM_EXPECTED=$(grep "rke2.${SUFFIX}.tar.gz" "${TMP_CHECKSUMS}" | awk '{print $1}')
CHECKSUM_ACTUAL=$(sha256sum "${TMP_TARBALL}" | awk '{print $1}')
if [ "${CHECKSUM_EXPECTED}" != "${CHECKSUM_ACTUAL}" ]; then
    fatal "RKE2 main tarball checksum does not match; expected ${CHECKSUM_EXPECTED}, got ${CHECKSUM_ACTUAL}"
fi
info "Main tarball verified successfully"

# Unpack main tarball
info "Unpacking RKE2 tarball to ${INSTALL_RKE2_TAR_PREFIX}"
mkdir -p "${INSTALL_RKE2_TAR_PREFIX}"
tar xzf "${TMP_TARBALL}" -C "${INSTALL_RKE2_TAR_PREFIX}"

# Install airgap tarball
mkdir -p "${INSTALL_RKE2_AGENT_IMAGES_DIR}"
info "Copying airgap images to ${INSTALL_RKE2_AGENT_IMAGES_DIR}"
mv -f "${TMP_AIRGAP_TARBALL}" "${INSTALL_RKE2_AGENT_IMAGES_DIR}/rke2-images.${SUFFIX}.tar.gz"

# Skip daemon reload and fapolicy configuration
info "Skipping daemon reload and fapolicy setup for standalone installation"

info "RKE2 standalone installation completed. Ensure paths are updated if needed."
exit 0
