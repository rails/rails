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
          (methods + private_methods + protected_methods).each do |m|
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

        class_eval <<-EOS, __FILE__, __LINE__ + 1
          include InstanceMethods                                                  # include InstanceMethods
                                                                                   #
          if method_defined?(:#{original_method})                                  # if method_defined?(:_unmemoized_mime_type)
            raise "Already memoized #{symbol}"                                     #   raise "Already memoized mime_type"
          end                                                                      # end
          alias #{original_method} #{symbol}                                       # alias _unmemoized_mime_type mime_type
                                                                                   #
          if instance_method(:#{symbol}).arity == 0                                # if instance_method(:mime_type).arity == 0
            def #{symbol}(reload = false)                                          #   def mime_type(reload = false)
              if reload || !defined?(#{memoized_ivar}) || #{memoized_ivar}.empty?  #     if reload || !defined?(@_memoized_mime_type) || @_memoized_mime_type.empty?
                #{memoized_ivar} = [#{original_method}.freeze]                     #       @_memoized_mime_type = [_unmemoized_mime_type.freeze]
              end                                                                  #     end
              #{memoized_ivar}[0]                                                  #     @_memoized_mime_type[0]
            end                                                                    #   end
          else                                                                     # else
            def #{symbol}(*args)                                                   #   def mime_type(*args)
              #{memoized_ivar} ||= {} unless frozen?                               #     @_memoized_mime_type ||= {} unless frozen?
              reload = args.pop if args.last == true || args.last == :reload       #     reload = args.pop if args.last == true || args.last == :reload
                                                                                   #
              if defined?(#{memoized_ivar}) && #{memoized_ivar}                    #     if defined?(@_memoized_mime_type) && @_memoized_mime_type
                if !reload && #{memoized_ivar}.has_key?(args)                      #       if !reload && @_memoized_mime_type.has_key?(args)
                  #{memoized_ivar}[args]                                           #         @_memoized_mime_type[args]
                elsif #{memoized_ivar}                                             #       elsif @_memoized_mime_type
                  #{memoized_ivar}[args] = #{original_method}(*args).freeze        #         @_memoized_mime_type[args] = _unmemoized_mime_type(*args).freeze
                end                                                                #       end
              else                                                                 #     else
                #{original_method}(*args)                                          #       _unmemoized_mime_type(*args)
              end                                                                  #     end
            end                                                                    #   end
          end                                                                      # end
                                                                                   #
          if private_method_defined?(#{original_method.inspect})                   # if private_method_defined?(:_unmemoized_mime_type)
            private #{symbol.inspect}                                              #   private :mime_type
          elsif protected_method_defined?(#{original_method.inspect})              # elsif protected_method_defined?(:_unmemoized_mime_type)
            protected #{symbol.inspect}                                            #   protected :mime_type
          end                                                                      # end
        EOS
      end
    end
  end
end
