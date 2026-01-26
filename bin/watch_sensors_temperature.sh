#!/bin/sh
# Copyright © 2025, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# watch sensors for CPU temperature
VERSION='0.001_000'

watch -n 3 sensors -f
