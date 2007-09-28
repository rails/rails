#!/usr/bin/env ruby

require 'builder/blankslate'

module Builder

  # Generic error for builder
  class IllegalBlockError < RuntimeError #:nodoc:
  end

  # XmlBase is a base class for building XML builders.  See
  # Builder::XmlMarkup and Builder::XmlEvents for examples.
  class XmlBase < BlankSlate #:nodoc:

    # Create an XML markup builder.
    #
    # out::     Object receiving the markup.  +out+ must respond to
    #           <tt><<</tt>.
    # indent::  Number of spaces used for indentation (0 implies no
    #           indentation and no line breaks).
    # initial:: Level of initial indentation.
    #
    def initialize(indent=0, initial=0)
      @indent = indent
      @level  = initial
    end
    
    # Create a tag named +sym+.  Other than the first argument which
    # is the tag name, the arguments are the same as the tags
    # implemented via <tt>method_missing</tt>.
    def tag!(sym, *args, &block)
      self.__send__(sym, *args, &block)
    end

    # Create XML markup based on the name of the method.  This method
    # is never invoked directly, but is called for each markup method
    # in the markup block.
    def method_missing(sym, *args, &block)
      text = nil
      attrs = nil
      sym = "#{sym}:#{args.shift}" if args.first.kind_of?(Symbol)
      args.each do |arg|
	case arg
	when Hash
	  attrs ||= {}
	  attrs.merge!(arg)
	else
	  text ||= ''
	  text << arg.to_s
	end
      end
      if block
	unless text.nil?
	  raise ArgumentError, "XmlMarkup cannot mix a text argument with a block"
	end
	_capture_outer_self(block) unless defined?(@self) && !@self.nil?
	_indent
	_start_tag(sym, attrs)
	_newline
	_nested_structures(block)
	_indent
	_end_tag(sym)
	_newline
      elsif text.nil?
	_indent
	_start_tag(sym, attrs, true)
	_newline
      else
	_indent
	_start_tag(sym, attrs)
	text! text
	_end_tag(sym)
	_newline
      end
      @target
    end

    # Append text to the output target.  Escape any markup.  May be
    # used within the markup brakets as:
    #
    #   builder.p { |b| b.br; b.text! "HI" }   #=>  <p><br/>HI</p>
    def text!(text)
      _text(_escape(text))
    end
    
    # Append text to the output target without escaping any markup.
    # May be used within the markup brakets as:
    #
    #   builder.p { |x| x << "<br/>HI" }   #=>  <p><br/>HI</p>
    #
    # This is useful when using non-builder enabled software that
    # generates strings.  Just insert the string directly into the
    # builder without changing the inserted markup.
    #
    # It is also useful for stacking builder objects.  Builders only
    # use <tt><<</tt> to append to the target, so by supporting this
    # method/operation builders can use other builders as their
    # targets.
    def <<(text)
      _text(text)
    end
    
    # For some reason, nil? is sent to the XmlMarkup object.  If nil?
    # is not defined and method_missing is invoked, some strange kind
    # of recursion happens.  Since nil? won't ever be an XML tag, it
    # is pretty safe to define it here. (Note: this is an example of
    # cargo cult programming,
    # cf. http://fishbowl.pastiche.org/2004/10/13/cargo_cult_programming).
    def nil?
      false
    end

    private
    
    require 'builder/xchar'
    def _escape(text)
      text.to_xs
    end

    def _escape_quote(text)
      _escape(text).gsub(%r{"}, '&quot;')  # " WART
    end

    def _capture_outer_self(block)
      @self = eval('self', block.instance_eval { binding })
    end

    def _newline
      return if @indent == 0
      text! "\n"
    end

    def _indent
      return if @indent == 0 || @level == 0
      text!(" " * (@level * @indent))
    end

    def _nested_structures(block)
      @level += 1
      block.call(self)
    ensure
      @level -= 1
    end
  end
end
