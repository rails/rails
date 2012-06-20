require 'active_support/core_ext/module/delegation'

module ActiveRecord
  module Delegation
    # Set up common delegations for performance (avoids method_missing)
    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to_ary, :to => :to_a
    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, :auto_explain_threshold_in_seconds, :to => :klass

    def self.delegate_to_scoped_klass(method)
      if method.to_s =~ /\A[a-zA-Z_]\w*[!?]?\z/
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)
            scoping { @klass.#{method}(*args, &block) }
          end
        RUBY
      else
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)
            scoping { @klass.send(#{method.inspect}, *args, &block) }
          end
        RUBY
      end
    end

    def respond_to?(method, include_private = false)
      super || Array.method_defined?(method) ||
        @klass.respond_to?(method, include_private) ||
        arel.respond_to?(method, include_private)
    end

    protected

    def method_missing(method, *args, &block)
      if @klass.respond_to?(method)
        ::ActiveRecord::Delegation.delegate_to_scoped_klass(method)
        scoping { @klass.send(method, *args, &block) }
      elsif Array.method_defined?(method)
        ::ActiveRecord::Delegation.delegate method, :to => :to_a
        to_a.send(method, *args, &block)
      elsif arel.respond_to?(method)
        ::ActiveRecord::Delegation.delegate method, :to => :arel
        arel.send(method, *args, &block)
      else
        super
      end
    end
  end
end
