module Regin
  class Collection
    include Enumerable

    def initialize(*args)
      @array = Array.new(*args)
    end

    def each
      @array.each{ |item| yield item }
    end

    def [](i)
      @array[i]
    end

    def length
      @array.length
    end
    alias_method :size, :length

    def first
      @array.first
    end

    def last
      @array.last
    end

    def +(other)
      ary = other.is_a?(self.class) ? other.internal_array : other
      self.class.new(@array + ary)
    end

    def to_regexp(anchored = false)
      re = to_s(true)
      re = "\\A#{re}\\Z" if anchored
      Regexp.compile(re, flags)
    end

    def match(char)
      to_regexp.match(char)
    end

    def include?(char)
      any? { |e| e.include?(char) }
    end

    def ==(other) #:nodoc:
      case other
      when String
        other == to_s
      when Array
        other == @array
      else
        eql?(other)
      end
    end

    def eql?(other) #:nodoc:
      other.instance_of?(self.class) && @array.eql?(other.internal_array)
    end

    def freeze #:nodoc:
      each { |e| e.freeze }
      @array.freeze
      super
    end

    protected
      def internal_array #:nodoc:
        @array
      end

      def extract_options(args)
        if args.last.is_a?(Hash)
          return args[0..-2], args.last
        else
          return args, {}
        end
      end
  end
end
