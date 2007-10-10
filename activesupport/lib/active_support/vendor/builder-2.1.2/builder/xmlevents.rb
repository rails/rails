#!/usr/bin/env ruby

#--
# Copyright 2004 by Jim Weirich (jim@weirichhouse.org).
# All rights reserved.

# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#++

require 'builder/xmlmarkup'

module Builder

  # Create a series of SAX-like XML events (e.g. start_tag, end_tag)
  # from the markup code.  XmlEvent objects are used in a way similar
  # to XmlMarkup objects, except that a series of events are generated
  # and passed to a handler rather than generating character-based
  # markup.
  #
  # Usage:
  #   xe = Builder::XmlEvents.new(hander)
  #   xe.title("HI")    # Sends start_tag/end_tag/text messages to the handler.
  #
  # Indentation may also be selected by providing value for the
  # indentation size and initial indentation level.
  #
  #   xe = Builder::XmlEvents.new(handler, indent_size, initial_indent_level)
  #
  # == XML Event Handler
  #
  # The handler object must expect the following events.
  #
  # [<tt>start_tag(tag, attrs)</tt>]
  #     Announces that a new tag has been found.  +tag+ is the name of
  #     the tag and +attrs+ is a hash of attributes for the tag.
  #
  # [<tt>end_tag(tag)</tt>]
  #     Announces that an end tag for +tag+ has been found.
  #
  # [<tt>text(text)</tt>]
  #     Announces that a string of characters (+text+) has been found.
  #     A series of characters may be broken up into more than one
  #     +text+ call, so the client cannot assume that a single
  #     callback contains all the text data.
  #
  class XmlEvents < XmlMarkup
    def text!(text)
      @target.text(text)
    end

    def _start_tag(sym, attrs, end_too=false)
      @target.start_tag(sym, attrs)
      _end_tag(sym) if end_too
    end

    def _end_tag(sym)
      @target.end_tag(sym)
    end
  end

end
