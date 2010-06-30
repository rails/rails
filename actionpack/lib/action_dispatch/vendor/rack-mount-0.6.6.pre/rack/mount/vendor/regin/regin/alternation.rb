module Regin
  class Alternation < Collection
    def initialize(*args)
      args, options = extract_options(args)

      if args.length == 1 && args.first.instance_of?(Array)
        super(args.first)
      else
        super(args)
      end

      if options.key?(:ignorecase)
        @array.map! { |e| e.dup(:ignorecase => options[:ignorecase]) }
      end
    end

    # Returns true if expression could be treated as a literal string.
    #
    # Alternation groups are never literal.
    def literal?
      false
    end

    def flags
      0
    end

    def dup(options = {})
      self.class.new(to_a, options)
    end

    def to_s(parent = false)
      map { |e| e.to_s(parent) }.join('|')
    end

    def inspect #:nodoc:
      to_s.inspect
    end
  end
end
