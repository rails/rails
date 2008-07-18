module ActiveSupport
  module Memoizable #:nodoc:
    def self.extended(obj)
      klass = obj.respond_to?(:class_eval) ? obj : obj.metaclass
      klass.class_eval do
        def freeze
          methods.each do |method|
            if m = method.to_s.match(/^unmemoized_(.*)/)
              send(m[1])
            end
          end
          super
        end
      end
    end

    def memoize(*symbols)
      symbols.each do |symbol|
        original_method = "unmemoized_#{symbol}"
        memoized_ivar = "@#{symbol}"

        klass = respond_to?(:class_eval) ? self : self.metaclass
        raise "Already memoized #{symbol}" if klass.instance_methods.map(&:to_s).include?(original_method)

        klass.class_eval <<-EOS, __FILE__, __LINE__
          alias_method :#{original_method}, :#{symbol}
          def #{symbol}(reload = false)
            if !reload && defined? #{memoized_ivar}
              #{memoized_ivar}
            else
              #{memoized_ivar} = #{original_method}.freeze
            end
          end
        EOS
      end
    end
  end
end
