#!/bin/sh

if [ -z "$1" ]; then
	echo "Usage: $0 connections/<db_library>" 1>&2
	exit 1
fi

ruby -I $1 -e 'Dir.foreach(".") { |file| require file if file =~ /_test.rb$/ }'
