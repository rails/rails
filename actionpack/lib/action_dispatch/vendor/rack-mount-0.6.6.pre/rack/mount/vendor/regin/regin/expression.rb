module Regin
  class Expression < Collection
    attr_reader :ignorecase, :multiline, :extended

    def initialize(*args)
      args, options = extract_options(args)

      @multiline = @ignorecase = @extended = nil

      if args.length == 1 && args.first.instance_of?(Array)
        super(args.first)
      else
        args = args.map { |e| e.instance_of?(String) ? Character.new(e) : e }
        super(args)
      end

      self.multiline  = options[:multiline] if options.key?(:multiline)
      self.ignorecase = options[:ignorecase] if options.key?(:ignorecase)
      self.extended   = options[:extended] if options.key?(:extended)
    end

    # Returns true if expression could be treated as a literal string.
    #
    # A Expression is literal if all its elements are literal.
    def literal?
      !ignorecase && all? { |e| e.literal? }
    end

    def anchored?
      anchored_to_start? && anchored_to_end?
    end

    def anchored_to_start?
      first.is_a?(Anchor) && first == '\A'
    end

    def anchored_to_end?
      last.is_a?(Anchor) && last == '\Z'
    end

    def anchored_to_line?
      anchored_to_start_of_line? && anchored_to_end_of_line?
    end

    def anchored_to_start_of_line?
      anchored_to_start? || (first.is_a?(Anchor) && first == '^')
    end

    def anchored_to_end_of_line?
      anchored_to_end? || (last.is_a?(Anchor) && last == '$')
    end

    def options?
      options.any?(true)
    end

    def flags
      options.to_i
    end

    def +(other)
      ary = other.is_a?(self.class) ? other.internal_array : other
      ary = @array + ary + [options.to_h(true)]
      self.class.new(*ary)
    end

    def dup(options = {})
      expression = super()
      expression.multiline  = options[:multiline] if options.key?(:multiline)
      expression.ignorecase = options[:ignorecase] if options.key?(:ignorecase)
      expression.extended   = options[:extended] if options.key?(:extended)
      expression
    end

    def to_s(parent = false)
      if parent || !options?
        map { |e| e.to_s(parent) }.join
      else
        with, without = [], []
        multiline ? (with << 'm') : (without << 'm')
        ignorecase ? (with << 'i') : (without << 'i')
        extended ? (with << 'x') : (without << 'x')

        with = with.join
        without = without.any? ? "-#{without.join}" : ''

        "(?#{with}#{without}:#{map { |e| e.to_s(true) }.join})"
      end
    end

    def inspect #:nodoc:
      "#<Expression #{to_s.inspect}>"
    end

    def casefold?
      ignorecase
    end

    def eql?(other) #:nodoc:
      super &&
        !!self.multiline == !!other.multiline &&
        !!self.ignorecase == !!other.ignorecase &&
        !!self.extended == !!other.extended
    end

    protected
      def options
        Options.new(multiline, ignorecase, extended)
      end

      def multiline=(multiline)
        @multiline = multiline
      end

      def ignorecase=(ignorecase)
        if @ignorecase.nil?
          @array.map! { |e| e.dup(:ignorecase => ignorecase) }
          @ignorecase = ignorecase
        end
      end

      def extended=(extended)
        @extended = extended
      end
  end
end
