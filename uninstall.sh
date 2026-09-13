#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "Removing macsmc fan control udev and tmpfiles rules..."
rm -f /etc/udev/rules.d/99-macsmc-fan.rules
rm -f /etc/tmpfiles.d/macsmc-fan.conf

udevadm control --reload-rules
udevadm trigger

echo "Successfully reverted fan control permissions to defaults."
