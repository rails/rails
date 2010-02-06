# lib/tmail/Makefile
#

debug:
	rm -f parser.rb
	make parser.rb DEBUG=true

parser.rb: parser.y
	if [ "$(DEBUG)" = true ]; then \
	    racc -v -g -o$@ parser.y ;\
	else \
	    racc -E -o$@ parser.y ;\
	fi

clean:
	rm -f parser.rb parser.output

distclean: clean
