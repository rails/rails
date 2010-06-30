module Regin
  class Character < Atom
    attr_reader :quantifier

    def initialize(value, options = {})
      @quantifier = options[:quantifier]
      super
    end

    def option_names
      %w( quantifier ) + super
    end

    # Returns true if expression could be treated as a literal string.
    #
    # A Character is literal is there is no quantifier attached to it.
    def literal?
      quantifier.nil? && !ignorecase
    end

    def to_s(parent = false)
      if !parent && ignorecase
        "(?i-mx:#{value})#{quantifier}"
      else
        "#{value}#{quantifier}"
      end
    end

    def to_regexp(anchored = false)
      re = to_s(true)
      re = "\\A#{re}\\Z" if anchored
      Regexp.compile(re, ignorecase)
    end

    def match(char)
      to_regexp(true).match(char)
    end

    def include?(char)
      if ignorecase
        value.downcase == char.downcase
      else
        value == char
      end
    end

    def eql?(other) #:nodoc:
      super && quantifier.eql?(other.quantifier)
    end

    def freeze #:nodoc:
      quantifier.freeze if quantifier
      super
    end
  end
end
