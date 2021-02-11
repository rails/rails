# frozen_string_literal: true

require "active_support/per_thread_registry"

module ActiveRecord
  module Scoping
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
    end

    module ClassMethods # :nodoc:
      # Collects attributes from scopes that should be applied when creating
      # an AR instance for the particular class this is called on.
      def scope_attributes
        all.scope_for_create
      end

      # Are there attributes associated with this scope?
      def scope_attributes?
        current_scope
      end

      def current_scope(skip_inherited_scope = false)
        ScopeRegistry.value_for(:current_scope, self, skip_inherited_scope)
      end

      def current_scope=(scope)
        ScopeRegistry.set_value_for(:current_scope, self, scope)
      end

      def global_current_scope(skip_inherited_scope = false)
        ScopeRegistry.value_for(:global_current_scope, self, skip_inherited_scope)
      end

      def global_current_scope=(scope)
        ScopeRegistry.set_value_for(:global_current_scope, self, scope)
      end
    end

    def populate_with_current_scope_attributes # :nodoc:
      return unless self.class.scope_attributes?

      attributes = self.class.scope_attributes
      _assign_attributes(attributes) if attributes.any?
    end

    def initialize_internals_callback # :nodoc:
      super
      populate_with_current_scope_attributes
    end

    # This class stores the +:current_scope+ and +:ignore_default_scope+ values
    # for different classes. The registry is stored as a thread local, which is
    # accessed through +ScopeRegistry.current+.
    #
    # This class allows you to store and get the scope values on different
    # classes and different types of scopes. For example, if you are attempting
    # to get the current_scope for the +Board+ model, then you would use the
    # following code:
    #
    #   registry = ActiveRecord::Scoping::ScopeRegistry
    #   registry.set_value_for(:current_scope, Board, some_new_scope)
    #
    # Now when you run:
    #
    #   registry.value_for(:current_scope, Board)
    #
    # You will obtain whatever was defined in +some_new_scope+. The #value_for
    # and #set_value_for methods are delegated to the current ScopeRegistry
    # object, so the above example code can also be called as:
    #
    #   ActiveRecord::Scoping::ScopeRegistry.set_value_for(:current_scope,
    #       Board, some_new_scope)
    class ScopeRegistry # :nodoc:
      extend ActiveSupport::PerThreadRegistry

      VALID_SCOPE_TYPES = [:current_scope, :ignore_default_scope, :global_current_scope]

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
      end

      # Obtains the value for a given +scope_type+ and +model+.
      def value_for(scope_type, model, skip_inherited_scope = false)
        raise_invalid_scope_type!(scope_type)
        return @registry[scope_type][model.name] if skip_inherited_scope
        klass = model
        base = model.base_class
        while klass <= base
          value = @registry[scope_type][klass.name]
          return value if value
          klass = klass.superclass
        end
      end

      # Sets the +value+ for a given +scope_type+ and +model+.
      def set_value_for(scope_type, model, value)
        raise_invalid_scope_type!(scope_type)
        @registry[scope_type][model.name] = value
      end

      private
        def raise_invalid_scope_type!(scope_type)
          if !VALID_SCOPE_TYPES.include?(scope_type)
            raise ArgumentError, "Invalid scope type '#{scope_type}' sent to the registry. Scope types must be included in VALID_SCOPE_TYPES"
          end
        end
    end
  end
end
