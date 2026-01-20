# OpenWrt Raspberry Pi Camera Feed

OpenWrt package feed for Raspberry Pi camera support using libcamera and rpicam-apps.

**Supported Hardware:**
- Raspberry Pi 5 (BCM2712) with Pi Camera v2/v3
- Raspberry Pi 4 (BCM2711) with Pi Camera v2/v3

## Packages

| Package | Description |
|---------|-------------|
| **libcamera** | Linux camera framework with `rpi/pisp` (Pi 5) and `rpi/vc4` (Pi 4) pipelines |
| **libpisp** | Pi 5 ISP helper library (auto-selected when using pisp pipeline) |
| **rpicam-apps** | Native camera apps: `rpicam-vid`, `rpicam-still`, `rpicam-hello`, `rpicam-raw` |
| **mediamtx** | RTSP/RTMP/HLS/WebRTC server (auto-starts on boot) |

---

## Quick Start: Pi 5 + Camera v3

### 1. Add the feed

Add to `feeds.conf.default`:
```
src-git pi5camera https://github.com/AndBobsYourUncle/openwrt-feed-pi5-camera.git
```

### 2. Update and install feeds

```bash
./scripts/feeds update -a
./scripts/feeds install -a
```

### 3. Base configuration

```bash
make menuconfig
```

Select:
- **Target System**: Broadcom BCM27xx
- **Subtarget**: BCM2712 boards (64 bit)
- **Target Profile**: Raspberry Pi 5
- **Target Images → Root filesystem partition size**: `256` (mediamtx is ~25MB)

### 4. Package selection

In `make menuconfig`, enable:

**Multimedia:**
- `libcamera` (Y)
  - `Raspberry Pi PiSP pipeline (Pi 5)` (Y)
- `rpicam-apps` (Y)
- `mediamtx` (Y)

**Global Build Settings:**
- `Compile with support for patented functionality` (Y) - required for libx264

**Utilities:**
- `ffmpeg` (Y) - for streaming

### 5. Kernel configuration

```bash
make kernel_menuconfig
```

Enable these options (built-in, not modules):

```
# Core infrastructure
CONFIG_PM=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y

# Pi 5 camera drivers
CONFIG_VIDEO_RP1_CFE=y
CONFIG_VIDEO_RASPBERRYPI_PISP_BE=y

# Camera sensors
CONFIG_VIDEO_IMX708=y          # Camera v3
CONFIG_VIDEO_IMX219=y          # Camera v2

# Autofocus (Camera v3)
CONFIG_VIDEO_DW9807_VCM=y
```

### 6. DMA Heap Fix (CRITICAL)

OpenWrt's debloat patch breaks DMA-BUF heaps. Create this fix:

```bash
cat > target/linux/generic/hack-6.12/905-fix-dmabuf-heaps.patch << 'EOF'
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

Without this, you'll see: `Could not open any dmaHeap device`

### 7. Device tree overlay

Ensure `target/linux/bcm27xx/image/distroconfig.txt` includes:

```ini
[pi5]
dtoverlay=imx708,cam0
```

For Camera v2, use `dtoverlay=imx219,cam0` instead.

### 8. Build

```bash
make -j$(nproc)
```

### 9. Flash and stream

After flashing, start an RTSP stream:

```bash
rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

View on another device:
```bash
ffplay -rtsp_transport tcp rtsp://<pi-ip>:8554/camera
```

> **Note:** Pi 5 lacks hardware H.264 encoding - software encoding (libx264) is required.

---

## Quick Start: Pi 4 + Camera v2/v3

### Differences from Pi 5

| Aspect | Pi 4 | Pi 5 |
|--------|------|------|
| Pipeline | `rpi/vc4` | `rpi/pisp` |
| libpisp | Not needed | Required |
| Hardware H.264 | Yes | No |
| CSI Driver | `VIDEO_BCM2835_UNICAM` | `VIDEO_RP1_CFE` |

### 1. Configuration changes

In `make menuconfig`:
- **Subtarget**: BCM2711 boards (64 bit)
- **Target Profile**: Raspberry Pi 4B

In **Multimedia → libcamera**:
- `Raspberry Pi VC4 pipeline (Pi 4)` (Y) instead of PiSP

### 2. Kernel configuration

```bash
make kernel_menuconfig
```

Enable for Pi 4:

```
CONFIG_PM=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y

# Pi 4 camera driver
CONFIG_VIDEO_BCM2835_UNICAM=y

# Camera sensors
CONFIG_VIDEO_IMX708=y          # Camera v3
CONFIG_VIDEO_IMX219=y          # Camera v2
CONFIG_VIDEO_DW9807_VCM=y      # Autofocus
```

### 3. Streaming (with hardware encoding)

Pi 4 has hardware H.264, so encoding is simpler:

```bash
rpicam-vid -t 0 --codec h264 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -i - -c:v copy -f rtsp rtsp://localhost:8554/camera
```

---

## Viewing Streams

```bash
# ffplay (recommended)
ffplay -rtsp_transport tcp rtsp://<pi-ip>:8554/camera

# VLC - MUST disable caching or you'll see blocky artifacts
vlc --network-caching=0 rtsp://<pi-ip>:8554/camera
```

> **VLC Warning:** Default caching causes visual artifacts. Always use `--network-caching=0`.

---

## mediamtx Service

mediamtx auto-starts on boot. Manage with:

```bash
/etc/init.d/mediamtx start|stop|restart|enable|disable
```

Config: `/etc/mediamtx/mediamtx.yml`

---

## Troubleshooting

### "Could not open any dmaHeap device"
Apply the DMA heap fix patch (see step 6 above).

### No /dev/video* devices
- Ensure `CONFIG_DEVTMPFS=y` and `CONFIG_DEVTMPFS_MOUNT=y` in kernel config
- Check device tree overlay is correct for your camera

### Camera not detected
- Verify ribbon cable connection (blue side toward contacts)
- CAM0 is the port closest to Ethernet on Pi 5
- Check `dmesg | grep -i imx` for sensor detection

### VLC shows blocky artifacts
Use `--network-caching=0` or switch to ffplay.

---

## Patches Included

| Patch | Purpose |
|-------|---------|
| `0001-libcamera-base-remove-support-for-libdw-and-libunwin.patch` | Prevent runtime errors from missing debug libs |
| `004-disable-ipa-signing.patch` | Cross-compilation compatibility |

---

## Dependencies

This feed requires `libdrm` from the base OpenWrt packages. If `libdrm` is not available in your build, you may need to add it manually or ensure the packages feed is installed.

---

## License

- libpisp: BSD-2-Clause
- libcamera: LGPL-2.1+ / GPL-2.0+ / BSD-2-Clause / MIT
- rpicam-apps: BSD-2-Clause
- mediamtx: MIT
