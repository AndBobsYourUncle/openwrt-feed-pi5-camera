# OpenWrt Pi 5 Camera Build

Base: `v25.12.0-rc2` (OpenWrt 25.12.0-rc2)

## Project Goal

Raspberry Pi 5 running OpenWrt as a travel router with camera support (Pi Camera v3).

### Key Differences from Pi 4

| Aspect | Pi 4 | Pi 5 |
|--------|------|------|
| SoC | BCM2711 | BCM2712 |
| Camera driver | `VIDEO_BCM2835_UNICAM_LEGACY` | `VIDEO_RP1_CFE` (via RP1 chip) |
| Hardware H.264 encoder | Yes (h264_v4l2m2m) | **No** |
| Encoding | Hardware via VideoCore | Software (libx264) |
| Kernel crash bug | Yes (codec buffer race) | **No** (no codec) |
| WiFi | Built-in brcmfmac | Built-in brcmfmac |
| PCIe | No | Yes (for WiFi card) |

---

## Hardware Setup

- **Camera**: Pi Camera v3 (IMX708) in CSI slot 0
- **WiFi Card**: Intel AX210NGW (PCIe M.2)

### WiFi Card Compatibility Notes

| Card | Status | Notes |
|------|--------|-------|
| Intel AX210NGW | **Works** | iwlwifi driver, good ARM64 support |
| MediaTek MT7925 | **Does NOT work** | DMA/IOMMU incompatibility with BCM2712 PCIe |

**MT7925 Issue**: The MT7925 PCIe WiFi card fails on Pi 5 with "Failed to get patch semaphore" errors. The root cause is that DMA transfers between the host and the MT7925's MCU don't work on Pi 5's BCM2712 PCIe/IOMMU implementation. Hardware register access works (wfsys_reset completes), but MCU commands sent via DMA never receive responses. This is a fundamental incompatibility requiring upstream kernel work.

---

## Build Process

### Tip: Use tmux for Long Builds

When building over SSH, use `tmux` to prevent builds from dying if your connection drops:

```bash
# Start a new tmux session
tmux new -s openwrt

# If disconnected, reattach later with:
tmux attach -t openwrt

# Detach without stopping: Ctrl+B, then D
```

---

### 1. Clone and Setup

```bash
cd /home/nicholas
git clone https://git.openwrt.org/openwrt/openwrt.git openwrt-pi5
cd openwrt-pi5
git checkout v25.12.0-rc2

./scripts/feeds update -a
./scripts/feeds install -a
```

### 2. Base Configuration

```bash
make menuconfig
```

Select:
- **Target System**: Broadcom BCM27xx
- **Subtarget**: BCM2712 boards (64 bit)
- **Target Profile**: Raspberry Pi 5

### 3. Kernel Configuration

```bash
make kernel_menuconfig
```

**Built-in (Y) - Core infrastructure:**
```
CONFIG_PM=y                             # Power Management (required by PISP_BE)
CONFIG_DEVTMPFS=y                       # Auto-create /dev nodes (CRITICAL)
CONFIG_DEVTMPFS_MOUNT=y                 # Mount devtmpfs at boot
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CONTROLLER=y
CONFIG_MEDIA_PLATFORM_SUPPORT=y
CONFIG_MEDIA_PLATFORM_DRIVERS=y
CONFIG_V4L_PLATFORM_DRIVERS=y           # V4L platform drivers (required by PISP_BE)
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_V4L2_SUBDEV_API=y
CONFIG_I2C=y
CONFIG_VIDEO_CAMERA_SENSOR=y
```

**Built-in (Y) - Camera drivers (Pi 5 specific):**
```
CONFIG_VIDEO_RP1_CFE=y                  # Pi 5 Camera Front End (captures from sensor)
CONFIG_VIDEO_RASPBERRYPI_PISP_BE=y      # PiSP Backend ISP (creates /dev/video* devices)
CONFIG_VIDEO_IMX708=y                   # Pi Camera v3 sensor
CONFIG_VIDEO_IMX219=y                   # Pi Camera v2 sensor (optional)
CONFIG_VIDEO_DW9807_VCM=y               # Lens driver (autofocus for Camera v3)
```

> **Important:** Pi 5 requires BOTH `VIDEO_RP1_CFE` (frontend) AND `VIDEO_RASPBERRYPI_PISP_BE` (backend ISP). Without PISP_BE, the CFE driver binds to the sensor but no `/dev/video*` devices are created.

> **Note:** Built as Y (not M) to avoid needing kmod package definitions. OpenWrt doesn't have existing package definitions for these camera modules.

### 4. Custom Defaults

Create files overlay for custom network defaults and auto-expand:

```bash
mkdir -p files/etc/uci-defaults

# Custom network config
cat > files/etc/uci-defaults/99-custom-network << 'EOF'
#!/bin/sh
uci set network.lan.ipaddr='10.10.20.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
exit 0
EOF
```

**Auto-expand root filesystem** (uses full SD card on first boot):

```bash
# Partition resize script
cat > files/etc/uci-defaults/70-rootpt-resize << 'EOF'
#!/bin/sh
if [ ! -e /etc/rootpt-resize ] \
&& type parted > /dev/null \
&& lock -n /var/lock/root-resize
then
ROOT_BLK="$(readlink -f /sys/dev/block/"$(awk -e \
'$9=="/dev/root"{print $3}' /proc/self/mountinfo)")"
ROOT_DISK="/dev/$(basename "${ROOT_BLK%/*}")"
ROOT_PART="${ROOT_BLK##*[^0-9]}"
parted -f -s "${ROOT_DISK}" resizepart "${ROOT_PART}" 100%
mount_root done
touch /etc/rootpt-resize
if [ -e /boot/cmdline.txt ]; then
NEW_UUID=`blkid ${ROOT_DISK}p${ROOT_PART} | sed -n 's/.*PARTUUID="\([^"]*\)".*/\1/p'`
sed -i "s/PARTUUID=[^ ]*/PARTUUID=${NEW_UUID}/" /boot/cmdline.txt
fi
reboot
fi
exit 1
EOF
chmod +x files/etc/uci-defaults/70-rootpt-resize

# Filesystem resize script
cat > files/etc/uci-defaults/80-rootfs-resize << 'EOF'
#!/bin/sh
if [ ! -e /etc/rootfs-resize ] \
&& [ -e /etc/rootpt-resize ] \
&& type losetup > /dev/null \
&& type resize2fs > /dev/null \
&& lock -n /var/lock/root-resize
then
ROOT_BLK="$(readlink -f /sys/dev/block/"$(awk -e \
'$9=="/dev/root"{print $3}' /proc/self/mountinfo)")"
ROOT_DEV="/dev/${ROOT_BLK##*/}"
LOOP_DEV="$(awk -e '$5=="/overlay"{print $9}' /proc/self/mountinfo)"
if [ -z "${LOOP_DEV}" ]; then
LOOP_DEV="$(losetup -f)"
losetup "${LOOP_DEV}" "${ROOT_DEV}"
fi
resize2fs -f "${LOOP_DEV}"
mount_root done
touch /etc/rootfs-resize
reboot
fi
exit 1
EOF
chmod +x files/etc/uci-defaults/80-rootfs-resize

# Preserve scripts across sysupgrade
cat > files/etc/sysupgrade.conf << 'EOF'
/etc/uci-defaults/70-rootpt-resize
/etc/uci-defaults/80-rootfs-resize
EOF
```

> **Note:** On first boot, the system will reboot twice (once after partition resize, once after filesystem resize), then the full SD card is available.

### 5. Package Selection

```bash
make menuconfig
```

**LuCI Web Interface:**
- `luci-ssl` (Y) - includes uhttpd + SSL

**WiFi - Built-in (STA mode):**
- `kmod-brcmfmac` (Y) - already enabled by default

**WiFi - PCIe Card (AP mode) - Intel AX210:**
- `kmod-iwlwifi` (Y) - Intel Wireless WiFi driver
- `iwlwifi-firmware-ax210` (Y) - AX210 firmware

**WiFi Supplicant:**
- `wpad-openssl` (M) - WPA supplicant + hostapd with full encryption

**WireGuard VPN:**
- `kmod-wireguard` (Y)
- `wireguard-tools` (Y)
- `luci-proto-wireguard` (Y)

**Utilities:**
- `iw-full` (Y)
- `usbutils` (Y)
- `v4l-utils` (Y) - includes media-ctl for camera pipeline configuration

**Filesystem Auto-Expand (to use full SD card):**
- `parted` (Y)
- `losetup` (Y)
- `blkid` (Y)
- `e2fsprogs` (Y) - includes resize2fs
- `resize2fs` (Y)

**Video/Streaming:**
- Under **Global Build Settings**: Enable `Compile with support for patented functionality` (required for x264)
- `libx264` (Y) - H.264 encoder library
- `ffmpeg` (Y) - for camera streaming with software encoding (will auto-include libx264)
- `rpicam-apps` (Y) - native libcamera video capture tools (recommended over v4l2-compat)
- `mediamtx` (Y) - RTSP/RTMP/HLS/WebRTC server (auto-starts on boot)

**Target Images:**
- Root filesystem partition size: `256` MiB (mediamtx is ~25MB, default 104 is too small)

### 6. distroconfig.txt (Pi 5 Settings)

The file `target/linux/bcm27xx/image/distroconfig.txt` should include Pi 5 specific settings:

```ini
[pi5]
# Camera overlay (cam0 = port closest to Ethernet)
dtoverlay=imx708,cam0
# Run as fast as firmware / board allows
arm_boost=1
```

> **Warning:** Do NOT add `pcie-32bit-dma-pi5` overlay - it breaks Intel AX210 WiFi cards (causes firmware init timeout). Only use it if you have a card that specifically fails with `-12 (ENOMEM)` DMA allocation errors.

### 7. DMA Heap Fix Patch (CRITICAL)

OpenWrt's debloat patch breaks DMA-BUF heaps compilation, which rpicam-apps needs for buffer allocation. Copy this fix:

```bash
cp /home/nicholas/openwrt/target/linux/generic/hack-6.12/905-fix-dmabuf-heaps.patch \
   target/linux/generic/hack-6.12/
```

Or create it manually:

```bash
cat > target/linux/generic/hack-6.12/905-fix-dmabuf-heaps.patch << 'EOF'
From: Nicholas <nicholas@local>
Subject: Fix dma-buf heaps build for camera support

The debloat patch breaks heaps/Makefile by using dma-buf-objs-y
instead of obj-y. Restore proper kbuild syntax so cma_heap and
system_heap get built.

--- a/drivers/dma-buf/heaps/Makefile
+++ b/drivers/dma-buf/heaps/Makefile
@@ -1,3 +1,3 @@
 # SPDX-License-Identifier: GPL-2.0
-dma-buf-objs-$(CONFIG_DMABUF_HEAPS_SYSTEM)	+= system_heap.o
-dma-buf-objs-$(CONFIG_DMABUF_HEAPS_CMA)		+= cma_heap.o
+obj-$(CONFIG_DMABUF_HEAPS_SYSTEM)	+= system_heap.o
+obj-$(CONFIG_DMABUF_HEAPS_CMA)		+= cma_heap.o
EOF
```

Without this patch, you'll see: `Could not open any dmaHeap device` when running rpicam-apps.

### 8. Kernel Config Lockdowns (Optional)

Prevent new kernel symbols from prompting during parallel builds:

```bash
cat >> target/linux/bcm27xx/bcm2712/config-6.12 << 'EOF'

# Prevent kernel config prompts during build
# CONFIG_SERIAL_RPI_FW is not set
# CONFIG_SPI_RP2040_GPIO_BRIDGE is not set
# CONFIG_GPIO_PWM is not set
# CONFIG_VIDEO_OV8858 is not set
# CONFIG_FB_RPISENSE is not set
EOF
```

### 8. Build

```bash
# First, resolve any new kernel config symbols (prevents prompts during parallel build)
make kernel_oldconfig

# Then build (tee saves output for debugging)
make -j$(nproc) V=s 2>&1 | tee build.log
```

---

## Status

- [x] Clone and checkout v25.12.0-rc2
- [x] Run feeds update/install
- [x] Configure target (menuconfig)
- [x] Configure kernel (kernel_menuconfig)
- [x] Add custom network defaults
- [x] Select packages
- [x] Build
- [x] Add distroconfig.txt Pi5 settings
- [x] Test Intel AX210 WiFi - **Working** (phy0)
- [x] Test onboard brcmfmac WiFi - **Working** (phy1)
- [x] Test camera on device - **Working** (8 CFE nodes + 16 PISP BE nodes registered)
- [x] Create pi5camera feed with libpisp + libcamera
- [x] Test camera streaming with libcamera v4l2-compat - **Working** (has buffer issues)
- [x] Add auto-expand filesystem scripts
- [x] Enable libx264 for H.264 encoding
- [x] Add rpicam-apps to feed for reliable video capture
- [x] Add DMA heap fix patch (905-fix-dmabuf-heaps.patch)
- [x] Add mediamtx to feed (pre-installed, auto-starts)
- [x] Test RTSP streaming with rpicam-apps + mediamtx - **Working**

### Output Images

```
bin/targets/bcm27xx/bcm2712/openwrt-bcm27xx-bcm2712-rpi-5-ext4-factory.img.gz
bin/targets/bcm27xx/bcm2712/openwrt-bcm27xx-bcm2712-rpi-5-squashfs-factory.img.gz
```

---

## Troubleshooting

### MT7925 WiFi Card (Does NOT Work on Pi 5)

If you see these errors in dmesg, the MT7925 is incompatible:
```
mt7925e 0001:01:00.0: Message 00000010 (seq 1) timeout
mt7925e 0001:01:00.0: Failed to get patch semaphore
```

**Root cause**: DMA transfers between host and MT7925 MCU fail on BCM2712's PCIe/IOMMU. Use Intel AX210 instead.

### PCIe DMA Allocation Errors (-12 ENOMEM)

If a PCIe card fails with `-12` during probe, ensure `pcie-32bit-dma-pi5` overlay is in distroconfig.txt.

---

## Camera Debugging History (RESOLVED)

### Initial Symptoms
- Camera hardware detected: `imx708 10-001a: camera module ID 0x0382`
- CFE driver loads: `rp1-cfe 1f00110000.csi: Using sensor imx708_wide_noir for capture`
- Video devices registered: `/dev/video0` through `/dev/video7` (CFE), `/dev/video20-35` (PISP BE)
- Media controller topology visible via `media-ctl -d /dev/media2 -p`
- DW9807 lens driver detected for autofocus

### Original Blocking Issue (Fixed)
**VIDIOC_STREAMON returns -32 (EPIPE / Broken pipe)**

Direct V4L2 streaming failed due to embedded data format validation in the CFE driver (IMMUTABLE links between sensor and csi2). The Pi 5 camera architecture requires libcamera for proper pipeline orchestration.

### Media Controller Setup Attempted

```bash
# View topology (media2 is the CFE, media0/1 are PISP BE)
media-ctl -d /dev/media2 -p

# Enable link from CSI to video0
media-ctl -d /dev/media2 -l '"csi2":4->"rp1-cfe-csi2_ch0":0[1]'

# Enable embedded metadata link
media-ctl -d /dev/media2 -l '"csi2":5->"rp1-cfe-embedded":0[1]'

# Set formats (must match across pipeline)
# IMX708 supported modes: 4608x2592, 2304x1296, 1536x864
media-ctl -d /dev/media2 -V '"imx708_wide_noir":0[fmt:SRGGB10_1X10/1536x864]'
media-ctl -d /dev/media2 -V '"csi2":0[fmt:SRGGB10_1X10/1536x864]'
media-ctl -d /dev/media2 -V '"csi2":4[fmt:SRGGB10_1X10/1536x864]'

# Set video device format (must match - 10-bit packed)
v4l2-ctl -d /dev/video0 --set-fmt-video=width=1536,height=864,pixelformat=pRAA

# Attempt capture
v4l2-ctl -d /dev/video0 --stream-mmap --stream-count=1 --stream-to=frame.raw
# Result: VIDIOC_STREAMON returned -1 (Broken pipe)
```

### Error Progression
1. `Invalid argument` - Format/resolution mismatch between pipeline stages
2. `Format mismatch!` - Pixel format mismatch (8-bit vs 10-bit)
3. `Broken pipe (-32)` - Pipeline configured but streaming fails

### Solution: libcamera Feed

Direct V4L2 streaming failed due to embedded data format validation in the CFE driver (IMMUTABLE links between sensor and csi2). The Pi 5 camera architecture requires libcamera for proper pipeline orchestration.

**Created custom feed**: `openwrt-feed-pi5-camera` with:
- `libpisp` - Pi 5 ISP helper library (v1.2.1)
- `libcamera` - Camera framework with PISP pipeline and v4l2-compat layer (v0.6.0)

See "Pi 5 Camera Feed Setup" section below for installation.

### Key Differences from Pi 4 Camera
| Aspect | Pi 4 | Pi 5 |
|--------|------|------|
| CSI Driver | `VIDEO_BCM2835_UNICAM_LEGACY` | `VIDEO_RP1_CFE` |
| ISP | `VIDEO_ISP_BCM2835` (staging) | `VIDEO_RASPBERRYPI_PISP_BE` |
| Architecture | Unicam → ISP → Output | CFE (via RP1) → PISP-FE → PISP-BE |
| Direct V4L2 | Works with v4l2-compat | Requires media controller setup |
| libcamera | Required for ISP processing | Likely required for pipeline init |

---

## Notes

- Pi 5's BCM2712 has strict PCIe/IOMMU requirements that some WiFi cards don't handle well
- Intel iwlwifi cards have better ARM64 compatibility than MediaTek mt76 cards for PCIe
- **Camera architecture**: Pi 5 camera goes through RP1 chip (via PCIe) → CFE driver → sensor. This is different from Pi 4 which uses BCM2835 Unicam directly.
- **CSI ports**: CAM0 is closest to Ethernet port, CAM1 is between CAM0 and HDMI
- **DEVTMPFS is critical**: Without it, `/dev/video*` nodes won't be created automatically

---

## Pi 5 Camera Feed Setup

### 1. Add the feed

Add to `feeds.conf.default`:
```
src-git pi5camera https://github.com/AndBobsYourUncle/openwrt-feed-pi5-camera.git
```

### 2. Update and install feeds

```bash
./scripts/feeds update pi5camera
./scripts/feeds install -a -p pi5camera
```

### 3. Configure packages

```bash
make menuconfig
```

Navigate to **Multimedia → libcamera** and enable:
- `libcamera` (Y)
- `Raspberry Pi PiSP pipeline (Pi 5)` (Y)

Navigate to **Multimedia → rpicam-apps** and enable:
- `rpicam-apps` (Y)

Navigate to **Multimedia → mediamtx** and enable:
- `mediamtx` (Y) - RTSP server (auto-starts on boot)

> **Note:** v4l2-compat is NOT needed - rpicam-apps uses libcamera's native API directly.

The `libpisp` package will be automatically selected as a dependency.

### 4. Build and flash

```bash
make -j$(nproc)
```

### 5. Test camera capture

After flashing, verify libcamera works with the v4l2-compat layer:

```bash
# Simple capture test
LD_PRELOAD=/usr/libexec/libcamera/v4l2-compat.so \
  ffmpeg -f v4l2 -video_size 1920x1080 -framerate 30 -i /dev/video0 \
  -frames:v 1 -f rawvideo test.raw
```

Expected output:
```
INFO Camera camera_manager.cpp:223 Adding camera '/base/axi/pcie@1000120000/rp1/i2c@88000/imx708@1a' for pipeline handler rpi/pisp
INFO RPI pisp.cpp:1181 Registered camera ... using PiSP variant BCM2712_D0
```

### 6. Feed Build Notes

The feed includes important fixes for cross-compilation:

1. **IPA signing disabled** (`004-disable-ipa-signing.patch`) - IPA module signing fails during cross-compilation and signed modules get invalidated when stripped

2. **Stripping disabled** (`RSTRIP:=:` in Makefile) - OpenWrt's strip corrupts the ELF symbol table that libcamera needs to load IPA modules

Without these fixes, you'll see: `ERROR IPAModule: IPA module has no valid info`

---

## RTSP Streaming with mediamtx

mediamtx is pre-installed and auto-starts on boot. Manage it with:
```bash
/etc/init.d/mediamtx start|stop|restart|enable|disable
```

Config file: `/etc/mediamtx/mediamtx.yml`

### Stream camera to RTSP (Recommended: rpicam-apps)

Use `rpicam-vid` for reliable video capture via libcamera's native API:

```bash
rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

### View stream

On another device:
```bash
# ffplay works best (recommended)
ffplay -rtsp_transport tcp rtsp://<pi5-ip>:8554/camera

# VLC on Mac/Linux - MUST disable caching or you'll see blocky artifacts
vlc --network-caching=0 rtsp://<pi5-ip>:8554/camera
```

> **Note:** Pi 5 does not have hardware H.264 encoding. Software encoding via libx264 is used instead. Ensure `BUILD_PATENTED` and `libx264` are enabled in the build config.

> **VLC Warning:** VLC's default network caching causes visual artifacts (blocky distortion). Always use `--network-caching=0` or use ffplay instead.

### Alternative: v4l2-compat (Optional, not recommended)

The v4l2-compat layer can also be used but may experience empty buffer errors:

```bash
LD_PRELOAD=/usr/libexec/libcamera/v4l2-compat.so \
  ffmpeg -f v4l2 -video_size 1920x1080 -framerate 30 -i /dev/video0 \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

If you see `Dequeued v4l2 buffer contains 0 bytes` errors, use the rpicam-apps method instead.

---

## What's Required vs Optional

### Required for rpicam-apps streaming:
- `libcamera` with PiSP pipeline
- `rpicam-apps`
- `mediamtx`
- `ffmpeg` with `libx264`
- DMA heap fix patch (`905-fix-dmabuf-heaps.patch`)
- Patches: `0001-libcamera-base-remove-support-for-libdw-and-libunwin.patch`, `004-disable-ipa-signing.patch`

### Optional (only needed for v4l2-compat fallback):
- `CONFIG_LIBCAMERA_V4L2=y` (v4l2 compatibility layer)
- Patches: `001-fix-musl-v4l2-compat.patch`, `002-fix-v4l2-compat-framedurationlimits-array.patch`, `003-fix-v4l2-compat-buffer-count-limit.patch`

The v4l2-compat layer was initially thought to be needed, but `rpicam-apps` provides a more reliable capture method using libcamera's native API. The v4l2-compat patches can be removed if you disable `CONFIG_LIBCAMERA_V4L2`.

---

## Build Hashes

| Image | SHA256 |
|-------|--------|
| ext4-factory.img.gz (clean build, v4l2-compat disabled) | `dac14ff19ebecff053aeafbe9ffb3b6c56e6b67cfe4a0563f9ca2a66d05070de` |
