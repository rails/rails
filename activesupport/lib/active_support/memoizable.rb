module ActiveSupport
  module Memoizable
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      def memoize(symbol)
        original_method = "_unmemoized_#{symbol}"
        memoized_ivar = "@_memoized_#{symbol}"
        raise "Already memoized #{symbol}" if instance_methods.map(&:to_s).include?(original_method)

        alias_method original_method, symbol
        class_eval <<-EOS, __FILE__, __LINE__
          def #{symbol}
            if defined? #{memoized_ivar}
              #{memoized_ivar}
            else
              #{memoized_ivar} = #{original_method}
            end
          end
        EOS
      end
    end

    def freeze
      methods.each do |method|
        if m = method.to_s.match(/\A_unmemoized_(.*)/)
          send(m[1]).freeze
        end
      end
      super
    end
  end
end
