# frozen_string_literal: true


module ActiveRecord
  module Delegation # :nodoc:
    class << self
      def delegated_classes
        [
          ActiveRecord::Relation,
          ActiveRecord::Associations::CollectionProxy,
          ActiveRecord::AssociationRelation,
          ActiveRecord::DisableJoinsAssociationRelation,
        ]
      end

      def uncacheable_methods
        @uncacheable_methods ||= (
          delegated_classes.flat_map(&:public_instance_methods) - ActiveRecord::Relation.public_instance_methods
        ).to_set.freeze
      end
    end

    module DelegateCache # :nodoc:
      @delegate_base_methods = true
      singleton_class.attr_accessor :delegate_base_methods

      def relation_delegate_class(klass)
        @relation_delegate_cache[klass]
      end

      def initialize_relation_delegate_cache
        @relation_delegate_cache = cache = {}
        Delegation.delegated_classes.each do |klass|
          delegate = Class.new(klass) {
            include ClassSpecificRelation
          }
          include_relation_methods(delegate)
          mangled_name = klass.name.gsub("::", "_")
          const_set mangled_name, delegate
          private_constant mangled_name

          cache[klass] = delegate
        end
      end

      def inherited(child_class)
        child_class.initialize_relation_delegate_cache
        super
      end

      def generate_relation_method(method)
        generated_relation_methods.generate_method(method)
      end

      protected
        def include_relation_methods(delegate)
          superclass.include_relation_methods(delegate) unless base_class?
          delegate.include generated_relation_methods
        end

      private
        def generated_relation_methods
          @generated_relation_methods ||= GeneratedRelationMethods.new.tap do |mod|
            const_set(:GeneratedRelationMethods, mod)
            private_constant :GeneratedRelationMethods
          end
        end
    end

    class GeneratedRelationMethods < Module # :nodoc:
      MUTEX = Mutex.new

      def generate_method(method)
        MUTEX.synchronize do
          return if method_defined?(method)

          if /\A[a-zA-Z_]\w*[!?]?\z/.match?(method) && !::ActiveSupport::Delegation::RESERVED_METHOD_NAMES.include?(method.to_s)
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(...)
                scoping { model.#{method}(...) }
              end
            RUBY
          else
            define_method(method) do |*args, **kwargs, &block|
              scoping { model.public_send(method, *args, **kwargs, &block) }
            end
          end
        end
      end
    end
    private_constant :GeneratedRelationMethods

    extend ActiveSupport::Concern

    # This module creates compiled delegation methods dynamically at runtime, which makes
    # subsequent calls to that method faster by avoiding method_missing. The delegations
    # may vary depending on the model of a relation, so we create a subclass of Relation
    # for each different model, and the delegations are compiled into that subclass only.

    delegate :to_xml, :encode_with, :length, :each, :join, :intersect?,
             :[], :&, :|, :+, :-, :sample, :reverse, :rotate, :compact, :in_groups, :in_groups_of,
             :to_sentence, :to_fs, :to_formatted_s, :as_json,
             :shuffle, :split, :slice, :index, :rindex, to: :records

    delegate :primary_key, :with_connection, :connection, :table_name, :transaction, :sanitize_sql_like, :unscoped, :name, to: :model

    module ClassSpecificRelation # :nodoc:
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        def name
          superclass.name
        end
      end

      private
        def method_missing(method, ...)
          if model.respond_to?(method)
            if !DelegateCache.delegate_base_methods && Base.respond_to?(method)
              # A common mistake in Active Record's own code is to call `ActiveRecord::Base`
              # class methods on Association. It works because it's automatically delegated, but
              # can introduce subtle bugs because it sets the global scope.
              # We can't deprecate this behavior because gems might depend on it, however we
              # can ban it from Active Record's own test suite to avoid regressions.
              raise NotImplementedError, "Active Record code shouldn't rely on association delegation into ActiveRecord::Base methods"
            elsif !Delegation.uncacheable_methods.include?(method)
              model.generate_relation_method(method)
            end

            scoping { model.public_send(method, ...) }
          else
            super
          end
        end
    end

    module ClassMethods # :nodoc:
      def create(model, ...)
        relation_class_for(model).new(model, ...)
      end

      private
        def relation_class_for(model)
          model.relation_delegate_class(self)
        end
    end

    private
      def respond_to_missing?(method, _)
        super || model.respond_to?(method)
      end
  end
end
