module ActiveRecord
  module Delegation # :nodoc:
    module DelegateCache # :nodoc:
      def relation_delegate_class(klass)
        @relation_delegate_cache[klass]
      end

      def initialize_relation_delegate_cache
        @relation_delegate_cache = cache = {}
        [
          ActiveRecord::Relation,
          ActiveRecord::Associations::CollectionProxy,
          ActiveRecord::AssociationRelation
        ].each do |klass|
          delegate = Class.new(klass) {
            include ClassSpecificRelation
          }
          mangled_name = klass.name.gsub("::".freeze, "_".freeze)
          const_set mangled_name, delegate
          private_constant mangled_name

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

    delegate :to_xml, :encode_with, :length, :collect, :map, :each, :all?, :include?, :to_ary, :join,
             :[], :&, :|, :+, :-, :sample, :reverse, :compact, :in_groups, :in_groups_of,
             :to_sentence, :to_formatted_s, :as_json,
             :shuffle, :split, :index, to: :records

    delegate :table_name, :quoted_table_name, :primary_key, :quoted_primary_key,
             :connection, :columns_hash, to: :klass

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

            if /\A[a-zA-Z_]\w*[!?]?\z/.match?(method)
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

      private

        def method_missing(method, *args, &block)
          if @klass.respond_to?(method)
            self.class.delegate_to_scoped_klass(method)
            scoping { @klass.public_send(method, *args, &block) }
          elsif arel.respond_to?(method)
            self.class.delegate method, to: :arel
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

    def respond_to_missing?(method, include_private = false)
      super || @klass.respond_to?(method, include_private) ||
        arel.respond_to?(method, include_private)
    end

    private

      def method_missing(method, *args, &block)
        if @klass.respond_to?(method)
          scoping { @klass.public_send(method, *args, &block) }
        elsif arel.respond_to?(method)
          arel.public_send(method, *args, &block)
        else
          super
        end
      end
  end
end
