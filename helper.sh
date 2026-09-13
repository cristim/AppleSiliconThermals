#!/usr/bin/env bash
set -euo pipefail

get_device_model() {
  local model="Apple Silicon Mac"
  if [[ -f /proc/device-tree/model ]]; then
    model=$(tr -d '\0' < /proc/device-tree/model | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  elif [[ -f /sys/firmware/devicetree/base/model ]]; then
    model=$(tr -d '\0' < /sys/firmware/devicetree/base/model | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  fi
  echo "${model//\"/\\\"}"
}

find_macsmc_hwmon() {
  local dir
  for dir in /sys/class/hwmon/hwmon*; do
    if [[ -f "$dir/name" ]] && grep -qx "macsmc_hwmon" "$dir/name" 2>/dev/null; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

is_apple_silicon() {
  if [[ -f /proc/device-tree/compatible ]] && grep -q "apple," /proc/device-tree/compatible 2>/dev/null; then
    return 0
  fi
  if [[ -f /proc/device-tree/model ]] && grep -q "^Apple" /proc/device-tree/model 2>/dev/null; then
    return 0
  fi
  if [[ -n "$HWMON_DIR" ]]; then
    return 0
  fi
  return 1
}

HWMON_DIR="$(find_macsmc_hwmon || true)"

cmd_get() {
  if ! is_apple_silicon; then
    printf '{"is_apple_silicon":false,"has_fan":false,"fan_count":0,"error":"unsupported_hardware","device_model":"Non-Apple Hardware"}\n'
    return 0
  fi

  local device_model
  device_model="$(get_device_model)"

  if [[ -z "$HWMON_DIR" || ! -d "$HWMON_DIR" ]]; then
    printf '{"is_apple_silicon":true,"has_fan":false,"fan_count":0,"error":"macsmc_hwmon_missing","device_model":"%s"}\n' "$device_model"
    return 0
  fi

  local fan_count=0
  local has_fan=false
  for f in "$HWMON_DIR"/fan*_input; do
    if [[ -f "$f" ]]; then
      fan_count=$((fan_count + 1))
    fi
  done
  if (( fan_count > 0 )); then
    has_fan=true
  fi

  local fan_rpm=0
  local fan_min=1199
  local fan_max=7199
  local fan_target=0
  local fan_control_enabled=false
  local manual_mode=false

  if [[ -f "$HWMON_DIR/fan1_input" ]]; then
    fan_rpm=$(cat "$HWMON_DIR/fan1_input" 2>/dev/null || echo 0)
  fi
  if [[ -f "$HWMON_DIR/fan1_min" ]]; then
    fan_min=$(cat "$HWMON_DIR/fan1_min" 2>/dev/null || echo 1199)
  fi
  if [[ -f "$HWMON_DIR/fan1_max" ]]; then
    fan_max=$(cat "$HWMON_DIR/fan1_max" 2>/dev/null || echo 7199)
  fi
  if [[ -f "$HWMON_DIR/fan1_target" ]]; then
    fan_target=$(cat "$HWMON_DIR/fan1_target" 2>/dev/null || echo 0)
  fi

  local fc_param="/sys/module/macsmc_hwmon/parameters/fan_control"
  if [[ -f "$fc_param" ]]; then
    local fc_val
    fc_val=$(cat "$fc_param" 2>/dev/null || echo "N")
    if [[ "$fc_val" == "Y" || "$fc_val" == "1" ]]; then
      fan_control_enabled=true
    fi
  fi

  if (( fan_target > 0 )); then
    manual_mode=true
  fi

  local temp_nand=0
  local temp_battery=0
  local temp_regulator=0
  local temp_wifi=0

  # Read labeled sensors
  local i=1
  while [[ -f "$HWMON_DIR/temp${i}_label" ]]; do
    local label input_val
    label=$(cat "$HWMON_DIR/temp${i}_label" 2>/dev/null || true)
    input_val=$(cat "$HWMON_DIR/temp${i}_input" 2>/dev/null || echo 0)
    # Convert milliCelsius to Celsius float
    local c_val
    c_val=$(awk "BEGIN { printf \"%.1f\", $input_val / 1000 }")
    case "$label" in
      *"NAND"*) temp_nand="$c_val" ;;
      *"Battery"*) temp_battery="$c_val" ;;
      *"Regulator"*) temp_regulator="$c_val" ;;
      *"WiFi"*|*"BT"*) temp_wifi="$c_val" ;;
    esac
    i=$((i + 1))
  done

  # Max temp across components
  local max_temp
  max_temp=$(awk "BEGIN {
    m = $temp_nand;
    if ($temp_battery > m) m = $temp_battery;
    if ($temp_regulator > m) m = $temp_regulator;
    if ($temp_wifi > m) m = $temp_wifi;
    printf \"%.1f\", m
  }")

  # Power consumption in Watts
  local power_val=0
  if [[ -f "$HWMON_DIR/power1_input" ]]; then
    local raw_p
    raw_p=$(cat "$HWMON_DIR/power1_input" 2>/dev/null || echo 0)
    power_val=$(awk "BEGIN { printf \"%.2f\", $raw_p / 1000000 }")
  fi

  printf '{"is_apple_silicon":true,"has_fan":%s,"fan_count":%d,"fan_rpm":%d,"fan_min":%d,"fan_max":%d,"fan_target":%d,"fan_control_enabled":%s,"manual_mode":%s,"max_temp":%s,"power_watts":%s,"device_model":"%s","sensors":{"nand":%s,"battery":%s,"regulator":%s,"wifi":%s}}\n' \
    "$has_fan" "$fan_count" "$fan_rpm" "$fan_min" "$fan_max" "$fan_target" "$fan_control_enabled" "$manual_mode" "$max_temp" "$power_val" "$device_model" \
    "$temp_nand" "$temp_battery" "$temp_regulator" "$temp_wifi"
}

cmd_set() {
  local target="${1:-auto}"
  if [[ -z "$HWMON_DIR" ]]; then
    echo "Error: macsmc_hwmon target not available" >&2
    return 1
  fi

  local targets=()
  for t in "$HWMON_DIR"/fan*_target; do
    if [[ -f "$t" ]]; then
      targets+=("$t")
    fi
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "Error: No fan target sysfs files found on this machine (fanless or unsupported)" >&2
    return 1
  fi

  if [[ "$target" == "auto" || "$target" == "0" ]]; then
    for t in "${targets[@]}"; do
      echo 0 > "$t"
    done
    echo "Fan control reset to automatic SMC mode"
    return 0
  fi

  # Validate numeric range
  if [[ "$target" =~ ^[0-9]+$ ]]; then
    local min max
    min=$(cat "$HWMON_DIR/fan1_min" 2>/dev/null || echo 1199)
    max=$(cat "$HWMON_DIR/fan1_max" 2>/dev/null || echo 7199)
    if (( target < min )); then target=$min; fi
    if (( target > max )); then target=$max; fi
    for t in "${targets[@]}"; do
      echo "$target" > "$t"
    done
    echo "Fan speed set to $target RPM across ${#targets[@]} fan(s)"
    return 0
  fi

  echo "Error: Invalid target '$target'. Specify RPM (1199-7199) or 'auto'." >&2
  return 1
}

cmd_setup() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run setup as root (sudo ./helper.sh setup)" >&2
    exit 1
  fi

  if ! is_apple_silicon; then
    echo "Error: Apple Silicon hardware (macsmc_hwmon) not detected." >&2
    echo "This plugin is designed only for Apple Silicon Macs running Linux." >&2
    exit 1
  fi

  echo "1. Enabling fan_control module parameter in runtime..."
  if [[ -f /sys/module/macsmc_hwmon/parameters/fan_control ]]; then
    echo 1 > /sys/module/macsmc_hwmon/parameters/fan_control
  fi

  echo "2. Persisting fan_control parameter across reboots in /etc/tmpfiles.d/macsmc-fan.conf..."
  mkdir -p /etc/tmpfiles.d
  cat <<'EOF' > /etc/tmpfiles.d/macsmc-fan.conf
w /sys/module/macsmc_hwmon/parameters/fan_control - - - - 1
EOF

  echo "3. Configuring udev rule for fan permissions in /etc/udev/rules.d/99-macsmc-fan.rules..."
  mkdir -p /etc/udev/rules.d
  cat <<'EOF' > /etc/udev/rules.d/99-macsmc-fan.rules
ACTION=="add|change", SUBSYSTEM=="hwmon", ATTRS{name}=="macsmc_hwmon", RUN+="/usr/bin/sh -c 'chmod 0666 /sys%p/fan*_target 2>/dev/null || true'"
EOF

  echo "4. Applying immediate permissions..."
  local hw
  hw="$(find_macsmc_hwmon || true)"
  if [[ -n "$hw" ]]; then
    chmod 0666 "$hw"/fan*_target 2>/dev/null || true
  fi

  echo "Setup complete! Manual fan control is now active and accessible to regular users."
}

case "${1:-get}" in
  get) cmd_get ;;
  set) cmd_set "${2:-auto}" ;;
  setup) cmd_setup ;;
  *)
    echo "Usage: $0 [get | set <rpm|auto> | setup]" >&2
    exit 1
    ;;
esac
