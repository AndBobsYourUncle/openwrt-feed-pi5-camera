#!/bin/sh

# Pi 5 camera stream - uses rpicam-apps + libx264 (no hardware encoder)
# Pi 4 camera stream - uses rpicam-apps + h264 hardware encoder

# Wait for MediaMTX to be ready
echo "Waiting for MediaMTX on port 8554..."
while ! netstat -tln 2>/dev/null | grep -q ':8554'; do
    sleep 1
done
echo "MediaMTX ready, starting stream..."
sleep 2

# Detect if hardware H.264 encoder is available (Pi 4 has it, Pi 5 doesn't)
if [ -e /dev/video11 ] && v4l2-ctl -d /dev/video11 --list-formats 2>/dev/null | grep -q H264; then
    echo "Using hardware H.264 encoder (Pi 4)"
    exec rpicam-vid -t 0 --codec h264 --width 1920 --height 1080 --framerate 30 -o - | \
        ffmpeg -i - -c:v copy -f rtsp rtsp://localhost:8554/camera
else
    echo "Using software H.264 encoder (Pi 5)"
    exec rpicam-vid -t 0 --codec yuv420 --width 1920 --height 1080 --framerate 30 -o - | \
        ffmpeg -f rawvideo -pix_fmt yuv420p -s 1920x1080 -r 30 -i - \
        -c:v libx264 -preset ultrafast -tune zerolatency -g 30 \
        -f rtsp rtsp://localhost:8554/camera
fi
