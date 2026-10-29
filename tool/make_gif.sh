#!/bin/sh
# Assemble doc/demo.gif from build/demo_frames (see tool/demo/generate_demo_test.dart).
set -e
cd "$(dirname "$0")/.."
FPS=12
ffmpeg -y -loglevel error -framerate $FPS -i build/demo_frames/f%04d.png \
  -vf "scale=360:-1:flags=lanczos,palettegen=max_colors=96:stats_mode=diff" build/palette.png
ffmpeg -y -loglevel error -framerate $FPS -i build/demo_frames/f%04d.png -i build/palette.png \
  -lavfi "scale=360:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 doc/demo.gif
ls -l doc/demo.gif
