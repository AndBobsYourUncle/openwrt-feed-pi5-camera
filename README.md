# OpenWrt Pi 5 Camera Feed

OpenWrt package feed for Raspberry Pi 5 camera support using libcamera, libpisp, and H.264 encoding.

## Packages

### libpisp
Raspberry Pi ISP (PiSP) helper library for Pi 5's Frontend and Backend ISP hardware.

### libcamera
Linux camera framework with Raspberry Pi support. Includes:
- **rpi/pisp** pipeline for Pi 5
- **rpi/vc4** pipeline for Pi 4
- **v4l2-compat** layer for using libcamera with V4L2 applications
- Patches for musl libc compatibility

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

Navigate to **Multimedia → libcamera** and enable:
- `libcamera` (Y)
- `Raspberry Pi PiSP pipeline (Pi 5)` (Y)
- `v4l2 compatibility layer` (Y)

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

### 5. Build

```bash
make -j$(nproc)
```

## Streaming with v4l2-compat

Once installed, use the v4l2 compatibility layer with FFmpeg:

```bash
LD_PRELOAD=/usr/libexec/libcamera/v4l2-compat.so \
  ffmpeg -f v4l2 -video_size 1920x1080 -framerate 30 -i /dev/video0 \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -f rtsp rtsp://localhost:8554/camera
```

Note: Pi 5 does not have hardware H.264 encoding, so software encoding (libx264) is required.

## Patches included

1. **musl v4l2-compat fix** - Symbol fallbacks for musl libc + DMA cache sync
2. **FrameDurationLimits array fix** - Handle control as array, not scalar
3. **Buffer count limit** - Cap buffers to avoid kernel limits
4. **libdw/libunwind removal** - Prevent runtime errors from missing debug libs

## License

- libpisp: BSD-2-Clause
- libcamera: LGPL-2.1+ / GPL-2.0+ / BSD-2-Clause / MIT
- libx264: GPL-2.0+ (requires BUILD_PATENTED=y)
