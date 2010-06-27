module Regin
  autoload :Alternation, 'regin/alternation'
  autoload :Anchor, 'regin/anchor'
  autoload :Atom, 'regin/atom'
  autoload :Character, 'regin/character'
  autoload :CharacterClass, 'regin/character_class'
  autoload :Collection, 'regin/collection'
  autoload :Expression, 'regin/expression'
  autoload :Group, 'regin/group'
  autoload :Options, 'regin/options'
  autoload :Parser, 'regin/parser'

  class << self
    begin
      eval('foo = /(?<foo>.*)/').named_captures

      # Returns true if the interpreter is using the Oniguruma Regexp lib
      # and supports named captures.
      #
      #   /(?<foo>bar)/
      def regexp_supports_named_captures?
        true
      end
    rescue SyntaxError, NoMethodError
      def regexp_supports_named_captures? #:nodoc:
        false
      end
    end

    # Parses Regexp and returns a Expression data structure.
    def parse(regexp)
      Parser.parse_regexp(regexp)
    end

    # Recompiles Regexp by parsing it and turning it back into a Regexp.
    #
    # (In the future Regin will perform some Regexp optimizations
    # such as removing unnecessary captures and options)
    def compile(source)
      regexp = Regexp.compile(source)
      expression = parse(regexp)
      Regexp.compile(expression.to_s(true), expression.flags)
    end
  end
end
