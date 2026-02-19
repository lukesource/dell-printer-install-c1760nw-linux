#!/bin/bash
#
# Dell C1760nw Color Laser Printer - Linux Install Script
#
# This printer is a rebranded Xerox Phaser 6000B that uses HBPLv1
# (Host-Based Printer Language version 1). The correct driver is
# foo2hbpl1 from the mikerr/foo2zjs GitHub fork.
#
# Tested on: Pop!_OS 22.04 (Ubuntu Noble), CUPS 2.4.7, Ghostscript 10.02.1
# Protocol: RAW socket (JetDirect) on port 9100
#
# Usage:
#   chmod +x install-dell-c1760nw.sh
#   sudo ./install-dell-c1760nw.sh [PRINTER_IP]
#
# Default IP: 192.168.4.30
#

set -euo pipefail

PRINTER_IP="${1:-192.168.4.30}"
PRINTER_NAME="DellC1760nw"
PRINTER_URI="socket://${PRINTER_IP}:9100"
PRINTER_INFO="Dell C1760nw Color Laser"
PRINTER_LOCATION="Network"

BUILD_DIR=$(mktemp -d)
SHARE_DIR=/usr/share/foo2hbpl
CRD_DIR="${SHARE_DIR}/crd"

cleanup() {
    echo "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

echo "============================================="
echo " Dell C1760nw Printer Install (HBPLv1)"
echo "============================================="
echo ""
echo "Printer IP: ${PRINTER_IP}"
echo "CUPS Name:  ${PRINTER_NAME}"
echo "URI:        ${PRINTER_URI}"
echo ""

# --------------------------------------------------
# Step 1: Check for root
# --------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root (sudo)."
    exit 1
fi

# --------------------------------------------------
# Step 2: Install dependencies
# --------------------------------------------------
echo "[1/7] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq \
    cups \
    cups-filters \
    printer-driver-foo2zjs-common \
    ghostscript \
    build-essential \
    libjbig-dev \
    git \
    > /dev/null
echo "       Done."

# --------------------------------------------------
# Step 3: Verify CUPS is running
# --------------------------------------------------
echo "[2/7] Verifying CUPS..."
systemctl enable --now cups > /dev/null 2>&1 || true
if ! systemctl is-active --quiet cups; then
    echo "ERROR: CUPS is not running."
    exit 1
fi
echo "       CUPS is active."

# --------------------------------------------------
# Step 4: Check printer is reachable
# --------------------------------------------------
echo "[3/7] Checking printer at ${PRINTER_IP}:9100..."
if ! timeout 5 bash -c "echo '' > /dev/tcp/${PRINTER_IP}/9100" 2>/dev/null; then
    echo "WARNING: Cannot reach ${PRINTER_IP}:9100."
    echo "         The printer may be off or on a different network."
    echo "         Continuing anyway — you can test later."
fi
echo "       Printer reachable."

# --------------------------------------------------
# Step 5: Build and install foo2hbpl1 from source
# --------------------------------------------------
echo "[4/7] Building foo2hbpl1 driver from source..."
cd "$BUILD_DIR"
git clone --depth 1 https://github.com/mikerr/foo2zjs.git foo2zjs 2>/dev/null
cd foo2zjs

# Build the foo2hbpl1 binary
gcc -O2 -o foo2hbpl1 foo2hbpl1.c -ljbig
echo "       Compiled foo2hbpl1."

# Install binary
install -m 755 foo2hbpl1 /usr/bin/foo2hbpl1

# Install wrapper script
install -m 755 foo2hbpl1-wrapper /usr/bin/foo2hbpl1-wrapper

echo "       Installed to /usr/bin/."

# --------------------------------------------------
# Step 6: Fix wrapper bug (undefined $SCREEN variable)
# --------------------------------------------------
echo "[5/7] Patching wrapper for Ghostscript compatibility..."
# The upstream wrapper has a bug: $SCREEN is never defined, so
# $CRDBASE/$SCREEN resolves to a directory path. Ghostscript
# chokes trying to load a directory as a PostScript file.
# Fix: only include the screen file path if $SCREEN is non-empty.
sed -i 's|^\(    GAMMAFILE="$GAMMAFILE $CRDBASE/$SCREEN"\)$|    if [ "$SCREEN" != "" ]; then\n\t\1\n    fi|' \
    /usr/bin/foo2hbpl1-wrapper
echo "       Patched."

# --------------------------------------------------
# Step 7: Install CRD/CMS color management files
# --------------------------------------------------
echo "[6/7] Installing color management files..."
mkdir -p "$CRD_DIR"

# CMS files (from crd/qpdl/ in the repo)
cp -f crd/qpdl/CLP-300cms          "$CRD_DIR/"
cp -f crd/qpdl/CLP-300-600x600cms2 "$CRD_DIR/"
cp -f crd/qpdl/CLP-300-1200x600cms2 "$CRD_DIR/"
cp -f crd/qpdl/CLP-300-1200x1200cms2 "$CRD_DIR/"
cp -f crd/qpdl/CLP-600cms          "$CRD_DIR/"
cp -f crd/qpdl/CLP-600-600x600cms2 "$CRD_DIR/"
cp -f crd/qpdl/CLP-600-1200x600cms2 "$CRD_DIR/"
cp -f crd/qpdl/CLP-600-1200x1200cms2 "$CRD_DIR/"
cp -f crd/qpdl/black-text.ps       "$CRD_DIR/"

# PostScript prolog and screen files (from crd/zjs/)
cp -f crd/zjs/prolog.ps            "$CRD_DIR/"
cp -f crd/zjs/screen1200.ps        "$CRD_DIR/"
cp -f crd/zjs/screen2400.ps        "$CRD_DIR/"

echo "       Installed to ${CRD_DIR}/."

# --------------------------------------------------
# Step 8: Configure CUPS printer queue
# --------------------------------------------------
echo "[7/7] Configuring CUPS printer..."

# Remove existing queue if present
lpadmin -x "$PRINTER_NAME" 2>/dev/null || true

# Add the printer with the Dell-C1760 PPD
lpadmin -p "$PRINTER_NAME" \
    -v "$PRINTER_URI" \
    -P "${BUILD_DIR}/foo2zjs/PPD/Dell-C1760.ppd" \
    -D "$PRINTER_INFO" \
    -L "$PRINTER_LOCATION" \
    -E

# Set as default printer
lpoptions -d "$PRINTER_NAME" > /dev/null 2>&1 || true

echo "       Printer queue '${PRINTER_NAME}' created."

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "============================================="
echo " Installation complete!"
echo "============================================="
echo ""
echo "Test commands:"
echo "  lp -d ${PRINTER_NAME} /path/to/file.pdf          # default (monochrome)"
echo "  lp -d ${PRINTER_NAME} -o ColorMode=Color file.pdf # color"
echo ""
echo "Quick test page:"
echo "  echo 'Hello from Linux!' | lp -d ${PRINTER_NAME}"
echo ""
echo "Verify status:"
echo "  lpstat -p ${PRINTER_NAME}"
echo ""
