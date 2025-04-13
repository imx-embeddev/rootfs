#!/bin/sh

cd /firmware/modules

echo "load driver modules..."
insmod sdriver_revision.ko
