module Regin
  class Group
    attr_reader :expression, :quantifier, :capture, :index, :name

    def initialize(expression, options = {})
      @quantifier = @index = @name = nil
      @capture = true
      @expression = expression.dup(options)

      @quantifier = options[:quantifier] if options.key?(:quantifier)
      @capture    = options[:capture] if options.key?(:capture)
      @index      = options[:index] if options.key?(:index)
      @name       = options[:name] if options.key?(:name)
    end

    def option_names
      %w( quantifier capture index name )
    end

    # Returns true if expression could be treated as a literal string.
    #
    # A Group is literal if its expression is literal and it has no quantifier.
    def literal?
      quantifier.nil? && expression.literal?
    end

    def to_s(parent = false)
      if !expression.options?
        "(#{capture ? '' : '?:'}#{expression.to_s(parent)})#{quantifier}"
      elsif capture == false
        "#{expression.to_s}#{quantifier}"
      else
        "(#{expression.to_s})#{quantifier}"
      end
    end

    def to_regexp(anchored = false)
      re = to_s
      re = "\\A#{re}\\Z" if anchored
      Regexp.compile(re)
    end

    def dup(options = {})
      original_options = option_names.inject({}) do |h, m|
        h[m.to_sym] = send(m)
        h
      end
      self.class.new(expression, original_options.merge(options))
    end

    def inspect #:nodoc:
      to_s.inspect
    end

    def match(char)
      to_regexp.match(char)
    end

    def include?(char)
      expression.include?(char)
    end

    def capture?
      capture
    end

    def ==(other) #:nodoc:
      case other
      when String
        other == to_s
      else
        eql?(other)
      end
    end

    def eql?(other) #:nodoc:
      other.is_a?(self.class) &&
        self.expression == other.expression &&
        self.quantifier == other.quantifier &&
        self.capture == other.capture &&
        self.index == other.index &&
        self.name == other.name
    end

    def freeze #:nodoc:
      expression.freeze if expression
      super
    end
  end
end
