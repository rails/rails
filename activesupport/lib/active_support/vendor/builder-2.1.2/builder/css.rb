#!/usr/bin/env ruby
#--
# Copyright 2004, 2005 by Jim Weirich  (jim@weirichhouse.org).
# Copyright       2005 by Scott Barron (scott@elitists.net).
# All rights reserved.
#
# Permission is granted for use, copying, modification, distribution,
# and distribution of modified versions of this work as long as the
# above copyright notice is included.
#
# Much of this is taken from Jim's work in xmlbase.rb and xmlmarkup.rb.
# Documentation has also been copied and pasted and modified to reflect
# that we're building CSS here instead of XML.  Jim is conducting the
# orchestra here and I'm just off in the corner playing a flute.
#++

# Provide a flexible and easy to use Builder for creating Cascading
# Style Sheets (CSS).


require 'builder/blankslate'

module Builder

  # Create a Cascading Style Sheet (CSS) using Ruby.
  #
  # Example usage:
  #
  #   css = Builder::CSS.new
  #
  #   text_color      = '#7F7F7F'
  #   preferred_fonts = 'Helvetica, Arial, sans_serif'
  #
  #   css.comment! 'This is our stylesheet'
  #   css.body {
  #     background_color '#FAFAFA'
  #     font_size        'small'
  #     font_family      preferred_fonts
  #     color            text_color
  #   }
  #
  #   css.id!('navbar') {
  #     width            '500px'
  #   }
  #
  #   css.class!('navitem') {
  #     color            'red'
  #   }
  #
  #   css.a :hover {
  #     text_decoration  'underline'
  #   }
  #
  #   css.div(:id => 'menu') {
  #     background       'green'
  #   }
  #
  #   css.div(:class => 'foo') {
  #     background       'red'
  #   }
  #
  # This will yield the following stylesheet:
  #
  #   /* This is our stylesheet */
  #   body {
  #     background_color: #FAFAFA;
  #     font_size:        small;
  #     font_family:      Helvetica, Arial, sans_serif;
  #     color:            #7F7F7F;
  #   }
  #
  #   #navbar {
  #     width:            500px;
  #   }
  #
  #   .navitem {
  #     color:            red;
  #   }
  #
  #   a:hover {
  #     text_decoration:  underline;
  #   }
  #
  #   div#menu {
  #     background:       green;
  #   }
  #
  #   div.foo {
  #     background:       red;
  #   }
  #
  class CSS < BlankSlate

    # Create a CSS builder.
    #
    # out::     Object receiving the markup.1  +out+ must respond to
    #           <tt><<</tt>.
    # indent::  Number of spaces used for indentation (0 implies no
    #           indentation and no line breaks).
    #
    def initialize(indent=2)
      @indent      = indent
      @target      = []
      @parts       = []
      @library     = {}
    end

    def +(part)
      _join_with_op! '+'
      self
    end

    def >>(part)
      _join_with_op! ''
      self
    end

    def >(part)
      _join_with_op! '>'
      self
    end

    def |(part)
      _join_with_op! ','
      self
    end

    # Return the target of the builder
    def target!
      @target * ''
    end

    # Create a comment string in the output.
    def comment!(comment_text)
      @target << "/* #{comment_text} */\n"
    end

    def id!(arg, &block)
      _start_container('#'+arg.to_s, nil, block_given?)
      _css_block(block) if block
      _unify_block
      self
    end

    def class!(arg, &block)
      _start_container('.'+arg.to_s, nil, block_given?)
      _css_block(block) if block
      _unify_block
      self
    end

    def store!(sym, &block)
      @library[sym] = block.to_proc
    end

    def group!(*args, &block)
      args.each do |arg|
        if arg.is_a?(Symbol)
          instance_eval(&@library[arg])
        else
          instance_eval(&arg)
        end
        _text ', ' unless arg == args.last
      end
      if block
        _css_block(block)
        _unify_block
      end
    end

    def method_missing(sym, *args, &block)
      sym = "#{sym}:#{args.shift}" if args.first.kind_of?(Symbol)
      if block
        _start_container(sym, args.first)
        _css_block(block)
        _unify_block
      elsif @in_block
        _indent
        _css_line(sym, *args)
        _newline
        return self
      else
        _start_container(sym, args.first, false)
        _unify_block
      end
      self
    end

    # "Cargo culted" from Jim who also "cargo culted" it.  See xmlbase.rb.
    def nil?
      false
    end

    private
    def _unify_block
      @target << @parts * ''
      @parts = []
    end

    def _join_with_op!(op)
      rhs, lhs = @target.pop, @target.pop
      @target << "#{lhs} #{op} #{rhs}"
    end

    def _text(text)
      @parts << text
    end

    def _css_block(block)
      _newline
      _nested_structures(block)
      _end_container
      _end_block
    end

    def _end_block
      _newline
      _newline
    end

    def _newline
      _text "\n"
    end

    def _indent
      _text ' ' * @indent
    end

    def _nested_structures(block)
      @in_block = true
      self.instance_eval(&block)
      @in_block = false
    end

    def _start_container(sym, atts = {}, with_bracket = true)
      selector = sym.to_s
      selector << ".#{atts[:class]}" if atts && atts[:class]
      selector << '#' + "#{atts[:id]}" if atts && atts[:id]
      @parts << "#{selector}#{with_bracket ? ' {' : ''}"
    end

    def _end_container
      @parts << "}"
    end

    def _css_line(sym, *args)
      _text("#{sym.to_s.gsub('_','-')}: #{args * ' '};")
    end
  end
end
