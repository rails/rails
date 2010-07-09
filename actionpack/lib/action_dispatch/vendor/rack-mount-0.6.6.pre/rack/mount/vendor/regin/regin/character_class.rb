module Regin
  class CharacterClass < Character
    def initialize(value, options = {})
      @negate = options[:negate]
      super
    end

    def option_names
      %w( negate ) + super
    end

    attr_reader :negate

    def negated?
      negate ? true : false
    end

    # Returns true if expression could be treated as a literal string.
    #
    # A CharacterClass is never literal.
    def literal?
      false
    end

    def bracketed?
      value != '.' && value !~ /^\\[dDsSwW]$/
    end

    def to_s(parent = false)
      if bracketed?
        if !parent && ignorecase
          "(?i-mx:[#{negate && '^'}#{value}])#{quantifier}"
        else
          "[#{negate && '^'}#{value}]#{quantifier}"
        end
      else
        super
      end
    end

    def include?(char)
      re = quantifier ? to_s.sub(/#{Regexp.escape(quantifier)}$/, '') : to_s
      Regexp.compile("\\A#{re}\\Z").match(char)
    end

    def eql?(other) #:nodoc:
      super && negate == other.negate
    end

    def freeze #:nodoc:
      negate.freeze if negate
      super
    end
  end
end
