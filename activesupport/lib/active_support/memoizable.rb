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
        memoize_all unless frozen?
        freeze_without_memoizable
      end

      def memoize_all
        methods.each do |m|
          if m.to_s =~ /^_unmemoized_(.*)/
            if method(m).arity == 0
              __send__($1)
            else
              ivar = :"@_memoized_#{$1}"
              instance_variable_set(ivar, {})
            end
          end
        end
      end

      def unmemoize_all
        methods.each do |m|
          if m.to_s =~ /^_unmemoized_(.*)/
            ivar = :"@_memoized_#{$1}"
            instance_variable_get(ivar).clear if instance_variable_defined?(ivar)
          end
        end
      end
    end

    def memoize(*symbols)
      symbols.each do |symbol|
        original_method = :"_unmemoized_#{symbol}"
        memoized_ivar = :"@_memoized_#{symbol.to_s.sub(/\?\Z/, '_query').sub(/!\Z/, '_bang')}"

        class_eval <<-EOS, __FILE__, __LINE__
          include Freezable

          raise "Already memoized #{symbol}" if method_defined?(:#{original_method})
          alias #{original_method} #{symbol}

          if instance_method(:#{symbol}).arity == 0
            def #{symbol}(reload = false)
              if reload || !defined?(#{memoized_ivar}) || #{memoized_ivar}.empty?
                #{memoized_ivar} = [#{original_method}.freeze]
              end
              #{memoized_ivar}[0]
            end
          else
            def #{symbol}(*args)
              #{memoized_ivar} ||= {} unless frozen?
              reload = args.pop if args.last == true || args.last == :reload

              if defined?(#{memoized_ivar}) && #{memoized_ivar}
                if !reload && #{memoized_ivar}.has_key?(args)
                  #{memoized_ivar}[args]
                elsif #{memoized_ivar}
                  #{memoized_ivar}[args] = #{original_method}(*args).freeze
                end
              else
                #{original_method}(*args)
              end
            end
          end
        EOS
      end
    end
  end
end
