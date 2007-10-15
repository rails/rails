#!/bin/sh

if [ -z "$1" ]; then
	echo "Usage: $0 <database>" 1>&2
	exit 1
fi

ruby -I connections/native_$1 -e 'Dir["**/*_test.rb"].each { |path| require path }'
