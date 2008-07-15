module ActiveSupport
  module Memoizable
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      def memorize(symbol)
        original_method = "_unmemorized_#{symbol}"
        alias_method original_method, symbol
        class_eval <<-EOS, __FILE__, __LINE__
          def #{symbol}
            if instance_variable_defined?(:@#{symbol})
              @#{symbol}
            else
              @#{symbol} = #{original_method}
            end
          end
        EOS
      end
    end

    def freeze
      methods.each do |method|
        if m = method.to_s.match(/^_unmemorized_(.*)/)
          send(m[1]).freeze
        end
      end
      super
    end
  end
end
