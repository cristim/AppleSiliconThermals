# 󰈐 AppleSiliconThermals

**Native hardware thermal monitoring and fan speed control plugin for [Omarchy Linux](https://omarchy.org/) on Apple Silicon (M1 / M2) MacBooks.**

Inspired by the macOS menu bar utility **Stats**, **AppleSiliconThermals** bridges the Asahi Linux `macsmc_hwmon` kernel driver with the modern Omarchy Quickshell status bar. It provides real-time sensor telemetry, a dynamic status bar indicator with rotational animation, and a popup control panel offering continuous fan curve control and quick presets.

---

## ✨ Features

- 󰈐 **Dynamic Status Bar Indicator**:
  - Compact fan icon (`󰈐`) seamlessly styled with active Omarchy theme tokens.
  - Dynamically spins smoothly when the fan is active; duration scales proportionally with current RPM.
  - Thermal color alerts: neutral when cool, warm amber (≥65°C), and urgent red (≥80°C).
  - Hover tooltip with live RPM and maximum temperature.

- 🎛️ **Dual-Mode Fan Control (macOS Stats Style)**:
  - **Automatic Mode**: Relaxes fan management back to Apple's calibrated hardware SMC algorithms.
  - **Manual Mode**: Precision continuous slider from **1,199 RPM to 7,199 RPM** with 50 RPM quantization snapping to values ending in **49** and **99** for authentic macOS Stats parity.
  - **Instant Preset Chips**:
    - `Auto`: Restores automatic SMC hardware management (`0 RPM` idle / dynamic).
    - `Quiet`: Fixes fan at whisper-quiet **25%** (`1,799 RPM`).
    - `Regular`: Balanced cooling at **50%** (`3,599 RPM`).
    - `Max`: High-performance cooling at **100%** (`7,199 RPM`) for compiling, gaming, or heavy workloads.

- 🌡️ **Comprehensive Hardware Telemetry**:
  - Live Fan Speed (Current RPM, Target RPM, Minimum & Maximum limits).
  - Component temperatures: **NAND Flash**, **Battery Hotspot**, **Charge Voltage Regulator**, and **Wi-Fi / Bluetooth Module**.
  - Real-time Total System Power dissipation in Watts (`W`).

- ⚡ **Zero External Dependencies**:
  - Communicates directly with the Linux kernel's standard `hwmon` sysfs interface (`macsmc_hwmon`).
  - No background Python or Node daemons required; lightweight shell backend.

---

## 🚀 Installation

### Option 1: Direct installation with Omarchy CLI

```bash
omarchy plugin add https://github.com/<your-github-username>/AppleSiliconThermals.git --enable
```

### Option 2: Manual clone into plugins directory

```bash
git clone https://github.com/<your-github-username>/AppleSiliconThermals.git ~/.config/omarchy/plugins/AppleSiliconThermals
omarchy plugin enable AppleSiliconThermals right
```

---

## ⚙️ One-Time Setup for Manual Fan Control

By default, the Linux kernel's `macsmc_hwmon` driver operates in read-only safe mode where the hardware SMC handles 100% of cooling decisions.

To unlock manual fan speed regulation without requiring `sudo` on every slider adjustment:

```bash
sudo ~/.config/omarchy/plugins/AppleSiliconThermals/setup.sh
```

This automated script:
1. Enables the runtime kernel parameter `macsmc_hwmon.fan_control=1`.
2. Persists the setting across reboots in `/etc/tmpfiles.d/macsmc-fan.conf`.
3. Installs a udev rule in `/etc/udev/rules.d/99-macsmc-fan.rules` granting your user permission to write to `fan1_target`.

---

## 🛠️ Repository & Publishing

To push and maintain this plugin on your personal GitHub account:

```bash
cd ~/.config/omarchy/plugins/AppleSiliconThermals
git init -b main
git add .
git commit -m "Initial release of AppleSiliconThermals plugin for Omarchy"
git remote add origin git@github.com:<your-username>/AppleSiliconThermals.git
git push -u origin main
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
