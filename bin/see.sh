#!/bin/bash

dir=$(dirname "$0")

"$dir/rpmsnapcmp.pl"  -r "$dir/../data/$(hostname)" latest- latest
