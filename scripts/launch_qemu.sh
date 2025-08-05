#!/bin/bash

# -enable-kvm = Use hardware acceleration.
# -m 4G = Share 4 GB RAM.
# -smp 4 = Share 4 CPU thread.

qemu-system-x86_64 -enable-kvm -m 4G -cdrom $1 -boot d -smp 4

