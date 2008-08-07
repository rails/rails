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
        unless frozen?
          methods.each do |method|
            if method.to_s =~ /^_unmemoized_(.*)/
              begin
                __send__($1)
              rescue ArgumentError
              end
            end
          end
        end

        freeze_without_memoizable
      end
    end

    def memoize(*symbols)
      symbols.each do |symbol|
        original_method = "_unmemoized_#{symbol}"
        memoized_ivar = "@_memoized_#{symbol.to_s.sub(/\?\Z/, '_query').sub(/!\Z/, '_bang')}"

        class_eval <<-EOS, __FILE__, __LINE__
          include Freezable

          raise "Already memoized #{symbol}" if method_defined?(:#{original_method})
          alias #{original_method} #{symbol}

          if instance_method(:#{symbol}).arity == 0
            def #{symbol}(reload = false)
              if !reload && defined? #{memoized_ivar}
                #{memoized_ivar}
              else
                #{memoized_ivar} = #{original_method}.freeze
              end
            end
          else
            def #{symbol}(*args)
              #{memoized_ivar} ||= {}
              reload = args.pop if args.last == true || args.last == :reload

              if !reload && #{memoized_ivar} && #{memoized_ivar}.has_key?(args)
                #{memoized_ivar}[args]
              else
                #{memoized_ivar}[args] = #{original_method}(*args).freeze
              end
            end
          end
        EOS
      end
    end
  end
end
