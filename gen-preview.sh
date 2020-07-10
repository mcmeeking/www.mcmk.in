#!/usr/bin/env bash

find ./static/images -mindepth 1 -type d | while read post; do
	
	echo "Found post $post"

	# Search for featured image in directory
	featured="$( find "${post}" -type f | grep featured )"

	# Create scaled featured image if not present
	if [[ -n "${featured}" ]] && [[ -f "${featured}" ]]; then
		
		echo "Only one featured file found, generating preview..."

		convert "$featured" -resize 480x600 "$( dirname "$featured" )/featured-preview.${featured//*./}"
	
	elif [[ -n "${featured}" ]]; then

		echo "Featured subset found as expected."
	
	else

		echo "No featured image found."

	fi
done
