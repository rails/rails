require 'active_support/concern'
require 'active_support/deprecation'

module ActiveRecord
  module Delegation # :nodoc:
    module DelegateCache
      def relation_delegate_class(klass) # :nodoc:
        @relation_delegate_cache[klass]
      end

      def initialize_relation_delegate_cache # :nodoc:
        @relation_delegate_cache = cache = {}
        [
          ActiveRecord::Relation,
          ActiveRecord::Associations::CollectionProxy,
          ActiveRecord::AssociationRelation
        ].each do |klass|
          delegate = Class.new(klass) {
            include ClassSpecificRelation
          }
          const_set klass.name.gsub('::', '_'), delegate
          cache[klass] = delegate
        end
      end

      def inherited(child_class)
        child_class.initialize_relation_delegate_cache
        super
      end
    end

    extend ActiveSupport::Concern

    # This module creates compiled delegation methods dynamically at runtime, which makes
    # subsequent calls to that method faster by avoiding method_missing. The delegations
    # may vary depending on the klass of a relation, so we create a subclass of Relation
    # for each different klass, and the delegations are compiled into that subclass only.

    delegate :&, :+, :[], :all?, :collect, :detect, :each, :each_cons,
             :each_with_index, :flat_map, :group_by, :include?, :length,
             :map, :none?, :one?, :reverse, :sample, :second, :sort, :sort_by,
             :to_ary, :to_set, :to_xml, :to_yaml, :to => :to_a

    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, :to => :klass

    module ClassSpecificRelation # :nodoc:
      extend ActiveSupport::Concern

      included do
        @delegation_mutex = Mutex.new
      end

      module ClassMethods # :nodoc:
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
              define_method method do |*args, &block|
                scoping { @klass.send(method, *args, &block) }
              end
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
        elsif arel.respond_to?(method)
          self.class.delegate method, :to => :arel
          arel.send(method, *args, &block)
        else
          super
        end
      end
    end

    module ClassMethods # :nodoc:
      def create(klass, *args)
        relation_class_for(klass).new(klass, *args)
      end

      private

      def relation_class_for(klass)
        klass.relation_delegate_class(self)
      end
    end

    def respond_to?(method, include_private = false)
      super || @klass.respond_to?(method, include_private) ||
        arel.respond_to?(method, include_private)
    end

    protected

    def method_missing(method, *args, &block)
      if @klass.respond_to?(method)
        scoping { @klass.send(method, *args, &block) }
      elsif arel.respond_to?(method)
        arel.send(method, *args, &block)
      else
        super
      end
    end
  end
end
