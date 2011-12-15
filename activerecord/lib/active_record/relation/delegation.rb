require 'active_support/core_ext/module/delegation'

module ActiveRecord
  module Delegation
    # These are explicitly delegated to improve performance (avoids method_missing)
    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to_ary, :to => :to_a
    delegate :ast, :engine, :to => :arel
    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, :auto_explain_threshold_in_seconds, :to => :klass

    def self.delegate_to_scoped_klass(method)
      if method.to_s =~ /[a-z]\w*!?/
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

    protected

    def method_missing(method, *args, &block)
      if Array.method_defined?(method)
        to_a.send(method, *args, &block)
      elsif @klass.respond_to?(method)
        ::ActiveRecord::Delegation.delegate_to_scoped_klass(method)
        scoping { @klass.send(method, *args, &block) }
      elsif arel.respond_to?(method)
        arel.send(method, *args, &block)
      else
        super
      end
    end
  end
end