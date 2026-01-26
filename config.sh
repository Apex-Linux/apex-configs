#!/bin/bash
# Exit if any command fails
set -e

# Activate NetworkManager so the ISO has internet out of the box
systemctl enable NetworkManager

echo "Apex Linux DNA successfully initialized!"
exit 0
