#!/bin/bash
set -euo pipefail

UNIT="applesiliconthermals-curve.service"

if (( EUID != 0 )); then
  echo "Please run as root: sudo $0"
  exit 1
fi

if [[ -n "${SUDO_USER:-}" ]]; then
  echo "Stopping the temperature curve service for $SUDO_USER..."
  # Fails when the user manager is not running or the unit was never installed.
  if ! systemctl --user -M "$SUDO_USER@" disable --now "$UNIT"; then
    echo "Could not disable $UNIT through the user manager; removing its files directly."
  fi
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  if [[ -z "$user_home" ]]; then
    echo "Error: cannot resolve the home directory of $SUDO_USER" >&2
    exit 1
  fi
  rm -f "$user_home/.config/systemd/user/$UNIT"
  rm -f "$user_home/.config/systemd/user/graphical-session.target.wants/$UNIT"
else
  echo "SUDO_USER is not set; skipping the per-user temperature curve service."
fi

echo "Removing macsmc fan control udev and tmpfiles rules..."
rm -f /etc/udev/rules.d/99-macsmc-fan.rules
rm -f /etc/tmpfiles.d/macsmc-fan.conf

# Release before disabling writes, even if the user manager was unavailable.
for hw in /sys/class/hwmon/hwmon*; do
  [[ -f "$hw/name" && $(<"$hw/name") == macsmc_hwmon ]] || continue
  for target in "$hw"/fan*_target; do
    [[ -f "$target" ]] || continue
    stem="${target%_target}"
    min="$(cat "${stem}_min")"
    max="$(cat "${stem}_max")"
    current="$(cat "$target")"
    [[ "$current" =~ ^[0-9]+$ ]] || current="$max"
    (( current >= min )) || current="$min"
    (( current <= max )) || current="$max"
    printf '%s\n' "$current" > "$target"
    printf '0\n' > "$target"
    chmod 0644 "$target"
  done
done
if [[ -f /sys/module/macsmc_hwmon/parameters/fan_control ]]; then
  printf '0\n' > /sys/module/macsmc_hwmon/parameters/fan_control
fi
udevadm control --reload-rules

echo "Returned fans to firmware and removed fan control setup."
