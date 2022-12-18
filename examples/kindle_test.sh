#!/bin/bash

../build/Linux-x86_64/stitch \
    -t kindle \
    -i '/media/rob/Kindle/documents/My Clippings.txt' \
    -o kindle.json

jq "." kindle.json
