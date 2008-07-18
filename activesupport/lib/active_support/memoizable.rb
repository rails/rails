module ActiveSupport
  module Memoizable
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      def memoize(*symbols)
        symbols.each do |symbol|
          original_method = "unmemoized_#{symbol}"
          memoized_ivar = "@#{symbol}"
          raise "Already memoized #{symbol}" if instance_methods.map(&:to_s).include?(original_method)

          alias_method original_method, symbol
          class_eval <<-EOS, __FILE__, __LINE__
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

    def freeze
      methods.each do |method|
        if m = method.to_s.match(/\Aunmemoized_(.*)/)
          send(m[1])
        end
      end
      super
    end
  end
end
