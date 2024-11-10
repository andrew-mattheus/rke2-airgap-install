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

# # Verify main tarball (commented out)
# CHECKSUM_EXPECTED=$(grep "rke2.${SUFFIX}.tar.gz" "${TMP_CHECKSUMS}" | awk '{print $1}')
# CHECKSUM_ACTUAL=$(sha256sum "${TMP_TARBALL}" | awk '{print $1}')
# if [ "${CHECKSUM_EXPECTED}" != "${CHECKSUM_ACTUAL}" ]; then
#     fatal "RKE2 main tarball checksum does not match; expected ${CHECKSUM_EXPECTED}, got ${CHECKSUM_ACTUAL}"
# fi
# info "Main tarball verified successfully"

# Unpack main tarball
info "Unpacking RKE2 tarball to ${INSTALL_RKE2_TAR_PREFIX}"
mkdir -p "${INSTALL_RKE2_TAR_PREFIX}"
tar xzf "${TMP_TARBALL}" -C "${INSTALL_RKE2_TAR_PREFIX}"

# Download or use local images file
if [ ! -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2-images-all.${SUFFIX}.txt" ]; then
    info "Downloading RKE2 images list from ${RKE2_IMAGES_URL}"
    curl -L -o "${TMP_AIRGAP_TARBALL}" "${RKE2_IMAGES_URL}"
else
    cp -f "${INSTALL_RKE2_ARTIFACT_PATH}/rke2-images-all.${SUFFIX}.txt" "${TMP_AIRGAP_TARBALL}"
fi

# # Verify airgap tarball (commented out)
# AIRGAP_CHECKSUM_EXPECTED=$(grep "rke2-images.${SUFFIX}.tar.gz" "${TMP_CHECKSUMS}" | awk '{print $1}')
# AIRGAP_CHECKSUM_ACTUAL=$(sha256sum "${TMP_AIRGAP_TARBALL}" | awk '{print $1}')
# if [ "${AIRGAP_CHECKSUM_EXPECTED}" != "${AIRGAP_CHECKSUM_ACTUAL}" ]; then
#     fatal "Airgap tarball checksum does not match; expected ${AIRGAP_CHECKSUM_EXPECTED}, got ${AIRGAP_CHECKSUM_ACTUAL}"
# fi
# info "Airgap tarball verified successfully"

# Copy airgap images
mkdir -p "${INSTALL_RKE2_AGENT_IMAGES_DIR}"
info "Copying airgap images to ${INSTALL_RKE2_AGENT_IMAGES_DIR}"
mv -f "${TMP_AIRGAP_TARBALL}" "${INSTALL_RKE2_AGENT_IMAGES_DIR}/rke2-images.${SUFFIX}.tar.gz"

# Skip daemon reload and fapolicy configuration
info "Skipping daemon reload and fapolicy setup for standalone installation"

info "RKE2 standalone installation completed. Ensure paths are updated if needed."
exit 0
