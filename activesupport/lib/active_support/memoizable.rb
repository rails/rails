module ActiveSupport
  module Memoizable
    module Freezable
      def self.included(base)
        base.class_eval do
          unless base.method_defined?(:freeze_without_memoizable)
            alias_method_chain :freeze, :memoizable
          end
        end
      end

      def freeze_with_memoizable
        methods.each do |method|
          __send__($1) if method.to_s =~ /^_unmemoized_(.*)/
        end unless frozen?

        freeze_without_memoizable
      end
    end

    def memoize(*symbols)
      symbols.each do |symbol|
        original_method = "_unmemoized_#{symbol}"
        memoized_ivar = "@_memoized_#{symbol}"

        class_eval <<-EOS, __FILE__, __LINE__
          include Freezable

          raise "Already memoized #{symbol}" if method_defined?(:#{original_method})
          alias #{original_method} #{symbol}

          def #{symbol}(*args)
            #{memoized_ivar} ||= {}
            reload = args.pop if args.last == true || args.last == :reload

            if !reload && #{memoized_ivar} && #{memoized_ivar}.has_key?(args)
              #{memoized_ivar}[args]
            else
              #{memoized_ivar}[args] = #{original_method}(*args).freeze
            end
          end
        EOS
      end
    end
  end
end
