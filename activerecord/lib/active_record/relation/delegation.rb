require 'set'
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

    BLACKLISTED_ARRAY_METHODS = [
      :compact!, :flatten!, :reject!, :reverse!, :rotate!, :map!,
      :shuffle!, :slice!, :sort!, :sort_by!, :delete_if,
      :keep_if, :pop, :shift, :delete_at, :compact
    ].to_set # :nodoc:

    delegate :to_xml, :to_yaml, :length, :collect, :map, :each, :all?, :include?, :to_ary, to: :to_a

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
                scoping { @klass.public_send(method, *args, &block) }
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
          scoping { @klass.public_send(method, *args, &block) }
        elsif arel.respond_to?(method)
          self.class.delegate method, :to => :arel
          arel.public_send(method, *args, &block)
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
        array_delegable?(method) ||
        arel.respond_to?(method, include_private)
    end

    protected

    def array_delegable?(method)
      Array.method_defined?(method) && BLACKLISTED_ARRAY_METHODS.exclude?(method)
    end

    def method_missing(method, *args, &block)
      if @klass.respond_to?(method)
        scoping { @klass.public_send(method, *args, &block) }
      elsif array_delegable?(method)
        to_a.public_send(method, *args, &block)
      elsif arel.respond_to?(method)
        arel.public_send(method, *args, &block)
      else
        super
      end
    end
  end
end
