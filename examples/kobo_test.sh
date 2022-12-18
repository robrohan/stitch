#!/bin/bash

# Input example:
# 	Kindle: '/media/rob/Kindle/documents/My Clippings.txt'
# 	Kobo: '/media/rob/KOBOeReader/.kobo/KoboReader.sqlite'


../build/Linux-x86_64/stitch \
    -t kobo \
    -i '/media/rob/KOBOeReader/.kobo/KoboReader.sqlite' \
    -o kobo.json

jq "." kobo.json
