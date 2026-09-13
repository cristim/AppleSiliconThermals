# 󰈐 AppleSiliconThermals

**Hardware thermal monitoring and fan speed control plugin for [Omarchy Linux](https://omarchy.org/) on Apple Silicon (M1 / M2) MacBooks.**

This plugin is inspired by the macOS menu bar utility **Stats** (https://mac-stats.com/).

**AppleSiliconThermals** bridges the Asahi Linux `macsmc_hwmon` kernel driver with the modern Omarchy Quickshell status bar. It provides real-time sensor telemetry, a dynamic status bar indicator with rotational animation, and a popup control panel offering continuous fan curve control and quick presets.

---

## Features

- 󰈐 **Dynamic Status Bar Indicator**:
  - Compact fan icon (`󰈐`) seamlessly styled with active Omarchy theme tokens.
  - Dynamically spins smoothly when the fan is active; duration scales proportionally with current RPM.
  - Thermal color alerts: neutral when cool, warm amber (≥65°C), and urgent red (≥80°C).
  - Hover tooltip with live RPM and maximum temperature.

- **Dual-Mode Fan Control (macOS Stats Style)**:
  - **Automatic Mode**: Relaxes fan management back to Apple's calibrated hardware SMC algorithms.
  - **Manual Mode**: Precision continuous slider from **1,199 RPM to 7,199 RPM** with 50 RPM quantization snapping to values ending in **49** and **99** for authentic macOS Stats parity.
  - **Instant Preset Chips**:
    - `Auto`: Restores automatic SMC hardware management (`0 RPM` idle / dynamic).
    - `Quiet`: Fixes fan at whisper-quiet **25%** (`1,799 RPM`).
    - `Regular`: Balanced cooling at **50%** (`3,599 RPM`).
    - `Max`: High-performance cooling at **100%** (`7,199 RPM`) for compiling, gaming, or heavy workloads.

- **Comprehensive Hardware Telemetry**:
  - Live Fan Speed (Current RPM, Target RPM, Minimum & Maximum limits).
  - Component temperatures: **NAND Flash**, **Battery Hotspot**, **Charge Voltage Regulator**, and **Wi-Fi / Bluetooth Module**.
  - Real-time Total System Power dissipation in Watts (`W`).

- ⚡ **Zero External Dependencies**:
  - Communicates directly with the Linux kernel's standard `hwmon` sysfs interface (`macsmc_hwmon`).
  - No background Python or Node daemons required; lightweight shell backend.

---

## Installation

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

## One-Time Setup for Manual Fan Control

By default, the Linux kernel's `macsmc_hwmon` driver operates in read-only safe mode where the hardware SMC handles 100% of cooling decisions.

To unlock manual fan speed regulation without requiring `sudo` on every slider adjustment:

> Before executing the script, feel free to read it, or ask your favorite agent on what it does, if you don't feel comfortable doing so

```bash
sudo ~/.config/omarchy/plugins/AppleSiliconThermals/setup.sh
```

This automated script:
1. Enables the runtime kernel parameter `macsmc_hwmon.fan_control=1`.
2. Persists the setting across reboots in `/etc/tmpfiles.d/macsmc-fan.conf`.
3. Installs a udev rule in `/etc/udev/rules.d/99-macsmc-fan.rules` granting your user permission to write to `fan1_target`.

---

## Hardware Compatibility & Community Testing

This plugin is purpose-built for Apple Silicon hardware running Linux. It dynamically adapts its UI depending on the detected Mac model and available cooling architecture:

| Hardware Category | Models | Supported Features | Status |
| :--- | :--- | :--- | :--- |
| **MacBook Pro** | 13" M1 (2020), 14"/16" M1/M2 Pro & Max | Live telemetry, spinning fan icon, continuous slider & presets | **Verified & Tested** |
| **MacBook Air** | 13"/15" M1 / M2 | Live component thermals & power; adapts to fanless mode (`󰔏` icon) | **Supported** |
| **Mac mini** | M1 / M2 / M2 Pro | Full fan control & thermal monitoring (Single fan) | **Community Testing** |
| **Mac Studio** | M1/M2 Max & Ultra | Synchronous dual-fan control & telemetry | **Call for Testing** |
| **Mac Pro** | M2 Ultra | Synchronous multi-fan control & telemetry | **Call for Testing** |
| **iMac** | 24" M1 (2-port & 4-port) | Single / dual-fan control & telemetry | **Call for Testing** |
| **Non-Apple / x86** | Standard PCs, VMs, Intel/AMD | Inactive warning icon (`󰌺`) & unsupported hardware notice | **Handled / Inactive** |

> **Do you own a Mac Studio, Mac mini, Mac Pro, or iMac?**
> Feedback is much appreciated! Please [open an issue](https://github.com/<your-username>/AppleSiliconThermals/issues) with your hardware details and test results to help refine multi-fan curves and fan channel independence.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
