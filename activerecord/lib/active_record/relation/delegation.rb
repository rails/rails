module ActiveRecord
  module Delegation # :nodoc:
    # Set up common delegations for performance (avoids method_missing)
    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to_ary, to: :to_a
    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, :auto_explain_threshold_in_seconds, to: :klass

    @@compiled_delegators = Set.new
    @@delegation_mutex = Mutex.new

    def respond_to?(method, include_private = false)
      # Check if `super` respond but the method is not in @@compiled_delegators,
      # because for @@compiled_delegators, `super` always return `true`, but
      # `method` itself sometimes returns `NoMethodError`.
      super_respond = super && @@delegation_mutex.synchronize do
        not @@compiled_delegators.include?(method)
      end
      super_respond ||
        Array.method_defined?(method) ||
        @klass.respond_to?(method, include_private) ||
        arel.respond_to?(method, include_private)
    end

    protected

    def method_missing(method, *args, &block)
      if @klass.respond_to?(method)
        @@delegation_mutex.synchronize do
          unless ::ActiveRecord::Delegation.method_defined?(method)
            ::ActiveRecord::Delegation.__send__(:delegate_to_scoped_klass, method)
          end
        end

        scoping { @klass.send(method, *args, &block) }
      elsif Array.method_defined?(method)
        @@delegation_mutex.synchronize do
          unless ::ActiveRecord::Delegation.method_defined?(method)
            ::ActiveRecord::Delegation.delegate method, to: :to_a
          end
        end

        to_a.send(method, *args, &block)
      elsif arel.respond_to?(method)
        @@delegation_mutex.synchronize do
          unless ::ActiveRecord::Delegation.method_defined?(method)
            ::ActiveRecord::Delegation.delegate method, to: :arel
          end
        end

        arel.send(method, *args, &block)
      else
        super
      end
    end

    class << self
      private

        def delegate_to_scoped_klass(method)
          # Keep `@@compiled_delegators` updating and method definition in the same
          # critical region to prevent inconsistency (when `@@compiled_delegators`
          # includes `:foo`, but `:foo` has not yet been defined).

          @@compiled_delegators << method

          if method.to_s =~ /\A[a-zA-Z_]\w*[!?]?\z/
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(*args, &block)
                if @klass.respond_to?(#{method.inspect})
                  scoping { @klass.#{method}(*args, &block) }
                elsif Array.method_defined?(#{method.inspect})
                  to_a.#{method}(*args, &block)
                elsif arel.respond_to?(#{method.inspect})
                  arel.#{method}(*args, &block)
                else
                  raise NoMethodError, "undefined method `#{method}` for \#{@klass}"
                end
              end
            RUBY
          else
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(*args, &block)
                if @klass.respond_to?(#{method.inspect})
                  scoping { @klass.send(#{method.inspect}, *args, &block) }
                elsif Array.method_defined?(#{method.inspect})
                  to_a.send(#{method.inspect}, *args, &block)
                elsif arel.respond_to?(#{method.inspect})
                  arel.send(#{method.inspect}, *args, &block)
                else
                  raise NoMethodError, "undefined method `#{method}` for \#{@klass}"
                end
              end
            RUBY
          end
        end
    end
  end
end
