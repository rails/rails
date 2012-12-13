require 'active_support/concern'
require 'thread'
require 'thread_safe'

module ActiveRecord
  module Delegation # :nodoc:
    extend ActiveSupport::Concern

    # This module creates compiled delegation methods dynamically at runtime, which makes
    # subsequent calls to that method faster by avoiding method_missing. The delegations
    # may vary depending on the klass of a relation, so we create a subclass of Relation
    # for each different klass, and the delegations are compiled into that subclass only.

    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to_ary, :to => :to_a
    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, :auto_explain_threshold_in_seconds, :to => :klass

    module ClassSpecificRelation
      extend ActiveSupport::Concern

      included do
        @delegation_mutex = Mutex.new
      end

      module ClassMethods
        def name
          superclass.name
        end

        def delegate_to_scoped_klass(method)
          @delegation_mutex.synchronize do
            return if method_defined?(method)

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
        end

        def delegate(method, opts = {})
          @delegation_mutex.synchronize do
            return if method_defined?(method)
            super
          end
        end
      end

      protected

      def method_missing(method, *args, &block)
        if @klass.respond_to?(method)
          self.class.delegate_to_scoped_klass(method)
          scoping { @klass.send(method, *args, &block) }
        elsif Array.method_defined?(method)
          self.class.delegate method, :to => :to_a
          to_a.send(method, *args, &block)
        elsif arel.respond_to?(method)
          self.class.delegate method, :to => :arel
          arel.send(method, *args, &block)
        else
          super
        end
      end
    end

    module ClassMethods
      @@subclasses = ThreadSafe::Cache.new(:initial_capacity => 2)

      def new(klass, *args)
        relation = relation_class_for(klass).allocate
        relation.__send__(:initialize, klass, *args)
        relation
      end

      # This doesn't have to be thread-safe. relation_class_for guarantees that this will only be
      # called exactly once for a given const name.
      def const_missing(name)
        const_set(name, Class.new(self) { include ClassSpecificRelation })
      end

      private
      # Cache the constants in @@subclasses because looking them up via const_get
      # make instantiation significantly slower.
      def relation_class_for(klass)
        if klass && (klass_name = klass.name)
          my_cache = @@subclasses.compute_if_absent(self) { ThreadSafe::Cache.new }
          # This hash is keyed by klass.name to avoid memory leaks in development mode
          my_cache.compute_if_absent(klass_name) do
            # Cache#compute_if_absent guarantees that the block will only executed once for the given klass_name
            const_get("#{name.gsub('::', '_')}_#{klass_name.gsub('::', '_')}", false)
          end
        else
          ActiveRecord::Relation
        end
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
        scoping { @klass.send(method, *args, &block) }
      elsif Array.method_defined?(method)
        to_a.send(method, *args, &block)
      elsif arel.respond_to?(method)
        arel.send(method, *args, &block)
      else
        super
      end
    end
  end
end
