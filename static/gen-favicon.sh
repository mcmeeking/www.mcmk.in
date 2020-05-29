#!/bin/bash
set -e

DIR="$(dirname "$0")"

cd "$DIR" || exit 1
if test -e favicon-1028x1028.png; then
    sips -z 16 16     favicon-1028x1028.png --out favicon-16x16.png
    sips -z 32 32     favicon-1028x1028.png --out favicon-32x32.png
    sips -z 48 48     favicon-1028x1028.png --out favicon.ico
    sips -z 150 150   favicon-1028x1028.png --out mstile-150x150.png
    sips -z 180 180   favicon-1028x1028.png --out apple-touch-icon.png
    sips -z 192 192   favicon-1028x1028.png --out android-chrome-192x192.png
    sips -z 512 512   favicon-1028x1028.png --out android-chrome-512x512.png
fi