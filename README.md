# OpenWrt Pi 5 Camera Feed

OpenWrt package feed for Raspberry Pi 5 camera support using libcamera, libpisp, rpicam-apps, and H.264 encoding.

## Packages

### libpisp
Raspberry Pi ISP (PiSP) helper library for Pi 5's Frontend and Backend ISP hardware.

### libcamera
Linux camera framework with Raspberry Pi support. Includes:
- **rpi/pisp** pipeline for Pi 5
- **rpi/vc4** pipeline for Pi 4

### rpicam-apps
Raspberry Pi camera applications using libcamera directly (recommended). Includes:
- **rpicam-vid** - Video capture (can output raw YUV to stdout for piping to ffmpeg)
- **rpicam-still** - Still image capture
- **rpicam-hello** - Camera preview/test
- **rpicam-raw** - Raw Bayer capture

### mediamtx
RTSP/RTMP/HLS/WebRTC media server. Auto-starts on boot.
- Config: `/etc/mediamtx/mediamtx.yml`
- Service: `/etc/init.d/mediamtx start|stop|restart`

### libx264
H.264/AVC video encoder library. Required for software H.264 encoding since Pi 5 lacks hardware encoding.
- Fixes upstream hash mismatch issue in OpenWrt packages feed

## Usage

### 1. Add the feed

Add to `feeds.conf.default`:
```
src-git pi5camera https://github.com/nicholasbalasus/openwrt-feed-pi5-camera.git
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

Navigate to **Multimedia** and enable:
- `libcamera` (Y) with `Raspberry Pi PiSP pipeline (Pi 5)` (Y)
- `rpicam-apps` (Y)
- `mediamtx` (Y)

**Target Images:**
- Root filesystem partition size: `256` MiB (mediamtx is ~25MB)

The `libpisp` package will be automatically selected as a dependency.

### 4. Kernel requirements

Ensure these kernel options are enabled for Pi 5 camera:

```
CONFIG_VIDEO_RP1_CFE=y
CONFIG_VIDEO_RASPBERRYPI_PISP_BE=y
CONFIG_VIDEO_IMX708=y              # Pi Camera v3
CONFIG_VIDEO_IMX219=y              # Pi Camera v2
CONFIG_VIDEO_DW9807_VCM=y          # Autofocus lens driver
CONFIG_PM=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
```

### 5. DMA Heap Fix (CRITICAL)

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

### 6. Build

```bash
make -j$(nproc)
```

## RTSP Streaming

mediamtx auto-starts on boot. Stream with rpicam-apps:

```bash
rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

View the stream:
```bash
# ffplay (recommended)
ffplay -rtsp_transport tcp rtsp://<pi-ip>:8554/camera

# VLC - MUST disable caching or you'll see artifacts
vlc --network-caching=0 rtsp://<pi-ip>:8554/camera
```

## Patches included

1. **libdw/libunwind removal** - Prevent runtime errors from missing debug libs
2. **IPA signing disabled** - Cross-compilation compatibility

Note: Pi 5 does not have hardware H.264 encoding, so software encoding (libx264) is required.

## License

- libpisp: BSD-2-Clause
- libcamera: LGPL-2.1+ / GPL-2.0+ / BSD-2-Clause / MIT
- libx264: GPL-2.0+ (requires BUILD_PATENTED=y)
- rpicam-apps: BSD-2-Clause
- mediamtx: MIT
