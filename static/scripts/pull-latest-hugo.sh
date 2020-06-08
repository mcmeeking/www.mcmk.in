#!/usr/bin/env bash

set -e

cd "$HOME" || ( echo "Failed to change to $HOME" ; exit 1 )

latest_url="$( curl -s https://github.com/gohugoio/hugo/releases | grep -Eo "/gohugoio/hugo/releases/download/(.*)hugo_extended(.*).deb" | sort -r | head -1 )"

curl -LO "https://github.com$latest_url"

exit 0