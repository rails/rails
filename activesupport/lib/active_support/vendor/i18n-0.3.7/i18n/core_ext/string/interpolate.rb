# encoding: utf-8

=begin
  heavily based on Masao Mutoh's gettext String interpolation extension
  http://github.com/mutoh/gettext/blob/f6566738b981fe0952548c421042ad1e0cdfb31e/lib/gettext/core_ext/string.rb
  Copyright (C) 2005-2009 Masao Mutoh
  You may redistribute it and/or modify it under the same license terms as Ruby.
=end

if RUBY_VERSION < '1.9'

  # KeyError is raised by String#% when the string contains a named placeholder
  # that is not contained in the given arguments hash. Ruby 1.9 includes and
  # raises this exception natively. We define it to mimic Ruby 1.9's behaviour
  # in Ruby 1.8.x

  class KeyError < IndexError
    def initialize(message = nil)
      super(message || "key not found")
    end
  end unless defined?(KeyError)

  # Extension for String class. This feature is included in Ruby 1.9 or later but not occur TypeError.
  #
  # String#% method which accept "named argument". The translator can know
  # the meaning of the msgids using "named argument" instead of %s/%d style.

  class String
    # For older ruby versions, such as ruby-1.8.5
    alias :bytesize :size unless instance_methods.find {|m| m.to_s == 'bytesize'}
    alias :interpolate_without_ruby_19_syntax :% # :nodoc:

    INTERPOLATION_PATTERN = Regexp.union(
      /%\{(\w+)\}/,                               # matches placeholders like "%{foo}"
      /%<(\w+)>(.*?\d*\.?\d*[bBdiouxXeEfgGcps])/  # matches placeholders like "%<foo>.d"
    )

    INTERPOLATION_PATTERN_WITH_ESCAPE = Regexp.union(
      /%%/,
      INTERPOLATION_PATTERN
    )

    # % uses self (i.e. the String) as a format specification and returns the
    # result of applying it to the given arguments. In other words it interpolates
    # the given arguments to the string according to the formats the string
    # defines.
    #
    # There are three ways to use it:
    #
    # * Using a single argument or Array of arguments.
    #
    #   This is the default behaviour of the String class. See Kernel#sprintf for
    #   more details about the format string.
    #
    #   Example:
    #
    #     "%d %s" % [1, "message"]
    #     # => "1 message"
    #
    # * Using a Hash as an argument and unformatted, named placeholders.
    #
    #   When you pass a Hash as an argument and specify placeholders with %{foo}
    #   it will interpret the hash values as named arguments.
    #
    #   Example:
    #
    #     "%{firstname}, %{lastname}" % {:firstname => "Masao", :lastname => "Mutoh"}
    #     # => "Masao Mutoh"
    #
    # * Using a Hash as an argument and formatted, named placeholders.
    #
    #   When you pass a Hash as an argument and specify placeholders with %<foo>d
    #   it will interpret the hash values as named arguments and format the value
    #   according to the formatting instruction appended to the closing >.
    #
    #   Example:
    #
    #     "%<integer>d, %<float>.1f" % { :integer => 10, :float => 43.4 }
    #     # => "10, 43.3"
    def %(args)
      if args.kind_of?(Hash)
        dup.gsub(INTERPOLATION_PATTERN_WITH_ESCAPE) do |match|
          if match == '%%'
            '%'
          else
            key = ($1 || $2).to_sym
            raise KeyError unless args.has_key?(key)
            $3 ? sprintf("%#{$3}", args[key]) : args[key]
          end
        end
      elsif self =~ INTERPOLATION_PATTERN
        raise ArgumentError.new('one hash required')
      else
        result = gsub(/%([{<])/, '%%\1')
        result.send :'interpolate_without_ruby_19_syntax', args
      end
    end
  end
end