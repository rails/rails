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

        class_eval <<-EOS, __FILE__, __LINE__ + 1
          include InstanceMethods

          raise "Already memoized #{symbol}" if method_defined?(:#{original_method}) # raise "Already memoized if_modified_since" if method_defined?(:__unmemoized_if_modified_since)
          alias #{original_method} #{symbol}                                         # alias __unmemoized_if_modified_since if_modified_since

          if instance_method(:#{symbol}).arity == 0                                  # if instance_method(:if_modified_since).arity == 0
            def #{symbol}(reload = false)                                            #   def if_modified_since(reload = false)
              if reload || !defined?(#{memoized_ivar}) || #{memoized_ivar}.empty?    #     if reload || !defined?(@_memoized_if_modified_since) || @_memoized_if_modified_since.empty?
                #{memoized_ivar} = [#{original_method}.freeze]                       #       @_memoized_if_modified_since = [__unmemoized_if_modified_since.freeze]
              end                                                                    #     end
              #{memoized_ivar}[0]                                                    #     @_memoized_if_modified_since[0]
            end                                                                      #   end
          else                                                                       # else
            def #{symbol}(*args)                                                     #   def if_modified_since(*args)
              #{memoized_ivar} ||= {} unless frozen?                                 #     @_memoized_if_modified_since ||= {} unless frozen?
              reload = args.pop if args.last == true || args.last == :reload         #     reload = args.pop if args.last == true || args.last == :reload
                                                                                     #
              if defined?(#{memoized_ivar}) && #{memoized_ivar}                      #     if defined?(@_memoized_if_modified_since) && @_memoized_if_modified_since
                if !reload && #{memoized_ivar}.has_key?(args)                        #       if !reload && @_memoized_if_modified_since.has_key?(args)
                  #{memoized_ivar}[args]                                             #         @_memoized_if_modified_since[args]
                elsif #{memoized_ivar}                                               #       elsif @_memoized_if_modified_since
                  #{memoized_ivar}[args] = #{original_method}(*args).freeze          #         @_memoized_if_modified_since[args] = __unmemoized_if_modified_since(*args).freeze
                end                                                                  #       end
              else                                                                   #     else
                #{original_method}(*args)                                            #       __unmemoized_if_modified_since(*args)
              end                                                                    #     end
            end                                                                      #   end
          end                                                                        # end
        EOS
      end
    end
  end
end
