#!/bin/bash
# Copyright © 2015, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

sudo sh -c "service ntp stop; ntpdate ntp.ubuntu.com; service ntp start"
