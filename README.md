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

### rpicam-apps
Raspberry Pi camera applications using libcamera directly. Includes:
- **rpicam-vid** - Video capture (can output raw YUV to stdout for piping to ffmpeg)
- **rpicam-still** - Still image capture
- **rpicam-hello** - Camera preview/test
- **rpicam-raw** - Raw Bayer capture

This is the recommended way to capture video, as it uses libcamera's native API rather than the v4l2-compat shim.

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

Navigate to **Multimedia → rpicam-apps** and enable:
- `rpicam-apps` (Y)

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

## Streaming with rpicam-apps (Recommended)

Use rpicam-vid to capture video and pipe to ffmpeg for encoding:

```bash
rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

For RTSP streaming, use [mediamtx](https://github.com/bluenviron/mediamtx):

```bash
# Download and run mediamtx
wget https://github.com/bluenviron/mediamtx/releases/download/v1.15.6/mediamtx_v1.15.6_linux_arm64.tar.gz -O mediamtx.tar.gz
tar xzf mediamtx.tar.gz
./mediamtx &

# Start the camera stream
rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
  ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
  -f rtsp rtsp://localhost:8554/camera
```

View the stream from another device:
```bash
ffplay rtsp://<pi-ip>:8554/camera
```

## Alternative: Streaming with v4l2-compat

The v4l2-compat layer can also be used, but may have buffer issues:

```bash
LD_PRELOAD=/usr/libexec/libcamera/v4l2-compat.so \
  ffmpeg -f v4l2 -video_size 1920x1080 -framerate 30 -i /dev/video0 \
  -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
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
- rpicam-apps: BSD-2-Clause
