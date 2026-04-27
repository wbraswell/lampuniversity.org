#!/usr/bin/bash
# Copyright © 2026, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# fix broken / crashed / locked audio in Xubuntu v24.04 (and possibly other versions)
VERSION='0.001_000'

# remove stale cache of broken plugins etc
rm -Rf ~/.cache/gstreamer-1.0

# restart broken PipeWire & PulseAudio connection
systemctl --user restart pipewire pipewire-pulse

# print PulseAudio info
pactl info

# test audio with sine wave beep
gst-launch-1.0 audiotestsrc wave=sine num-buffers=100 ! audioconvert ! pipewireasink

# test Pithos with debug output
GST_PLUGIN_FEATURE_RANK=pwasink:MAX pithos -v
