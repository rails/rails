module Rack::Mount
  if Regin.regexp_supports_named_captures?
    RegexpWithNamedGroups = Regexp
  else
    require 'strscan'

    # A wrapper that adds shim named capture support to older
    # versions of Ruby.
    #
    # Because the named capture syntax causes a parse error, an
    # alternate syntax is used to indicate named captures.
    #
    # Ruby 1.9+ named capture syntax:
    #
    #   /(?<foo>[a-z]+)/
    #
    # Ruby 1.8 shim syntax:
    #
    #   /(?:<foo>[a-z]+)/
    class RegexpWithNamedGroups < Regexp
      def self.new(regexp) #:nodoc:
        if regexp.is_a?(RegexpWithNamedGroups)
          regexp
        else
          super
        end
      end

      # Wraps Regexp with named capture support.
      def initialize(regexp)
        regexp = Regexp.compile(regexp) unless regexp.is_a?(Regexp)
        source, options = regexp.source, regexp.options
        @names, scanner = [], StringScanner.new(source)

        while scanner.skip_until(/\(/)
          if scanner.scan(/\?:<([^>]+)>/)
            @names << scanner[1]
          elsif scanner.scan(/\?(i?m?x?\-?i?m?x?)?:/)
            # ignore noncapture
          else
            @names << nil
          end
        end
        source.gsub!(/\?:<([^>]+)>/, '')

        @names = [] unless @names.any?
        @names.freeze

        super(source, options)
      end

      def names
        @names.dup
      end

      def named_captures
        named_captures = {}
        names.each_with_index { |n, i|
          named_captures[n] = [i+1] if n
        }
        named_captures
      end

      def eql?(other)
        super && @names.eql?(other.names)
      end
    end
  end
end
