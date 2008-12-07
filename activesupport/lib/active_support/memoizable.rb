module ActiveSupport
  module Memoizable
    def self.memoized_ivar_for(symbol)
      "@_memoized_#{symbol.to_s.sub(/\?\Z/, '_query').sub(/!\Z/, '_bang')}".to_sym
    end

    module InstanceMethods
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
        prime_cache ".*"
      end

      def unmemoize_all
        flush_cache ".*"
      end

      def prime_cache(*syms)
        syms.each do |sym|
          methods.each do |m|
            if m.to_s =~ /^_unmemoized_(#{sym})/
              if method(m).arity == 0
                __send__($1)
              else
                ivar = ActiveSupport::Memoizable.memoized_ivar_for($1)
                instance_variable_set(ivar, {})
              end
            end
          end
        end
      end

      def flush_cache(*syms, &block)
        syms.each do |sym|
          methods.each do |m|
            if m.to_s =~ /^_unmemoized_(#{sym})/
              ivar = ActiveSupport::Memoizable.memoized_ivar_for($1)
              instance_variable_get(ivar).clear if instance_variable_defined?(ivar)
            end
          end
        end
      end
    end

    def memoize(*symbols)
      symbols.each do |symbol|
        original_method = :"_unmemoized_#{symbol}"
        memoized_ivar = ActiveSupport::Memoizable.memoized_ivar_for(symbol)

        class_eval <<-EOS, __FILE__, __LINE__
          include InstanceMethods

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
