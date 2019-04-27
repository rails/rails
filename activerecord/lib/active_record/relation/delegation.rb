# frozen_string_literal: true

require "mutex_m"

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
      include Mutex_m

      def generate_method(method)
        synchronize do
          return if method_defined?(method)

          if /\A[a-zA-Z_]\w*[!?]?\z/.match?(method)
            module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def #{method}(*args, &block)
                scoping { klass.#{method}(*args, &block) }
              end
            RUBY
          else
            define_method(method) do |*args, &block|
              scoping { klass.public_send(method, *args, &block) }
            end
          end
        end
      end
    end
    private_constant :GeneratedRelationMethods

    extend ActiveSupport::Concern

    # This module creates compiled delegation methods dynamically at runtime, which makes
    # subsequent calls to that method faster by avoiding method_missing. The delegations
    # may vary depending on the klass of a relation, so we create a subclass of Relation
    # for each different klass, and the delegations are compiled into that subclass only.

    delegate :to_xml, :encode_with, :length, :each, :join,
             :[], :&, :|, :+, :-, :sample, :reverse, :rotate, :compact, :in_groups, :in_groups_of,
             :to_sentence, :to_formatted_s, :as_json,
             :shuffle, :split, :slice, :index, :rindex, to: :records

    delegate :primary_key, :connection, to: :klass

    module ClassSpecificRelation # :nodoc:
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        def name
          superclass.name
        end
      end

      private

        def method_missing(method, *args, &block)
          if @klass.respond_to?(method)
            @klass.generate_relation_method(method)
            scoping { @klass.public_send(method, *args, &block) }
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

    private
      def respond_to_missing?(method, _)
        super || @klass.respond_to?(method)
      end
  end
end
