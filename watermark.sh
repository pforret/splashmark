#!/usr/bin/env bash

[[ ! $(command -v splashmark) ]] && echo "Requires pforret/splashmark" && exit 1
year=$(date +%Y)
name="Peter Forret"
splashmark -3 "$year $name" folder "$PWD"