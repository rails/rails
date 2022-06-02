# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

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
        ScopeRegistry.current_scope(self, skip_inherited_scope)
      end

      def current_scope=(scope)
        ScopeRegistry.set_current_scope(self, scope)
      end

      def global_current_scope(skip_inherited_scope = false)
        ScopeRegistry.global_current_scope(self, skip_inherited_scope)
      end

      def global_current_scope=(scope)
        ScopeRegistry.set_global_current_scope(self, scope)
      end

      def scope_registry
        ScopeRegistry.instance
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
    # for different classes. The registry is stored as either a thread or fiber
    # local depending on the application configuration.
    #
    # This class allows you to store and get the scope values on different
    # classes and different types of scopes. For example, if you are attempting
    # to get the current_scope for the +Board+ model, then you would use the
    # following code:
    #
    #   registry = ActiveRecord::Scoping::ScopeRegistry
    #   registry.set_current_scope(Board, some_new_scope)
    #
    # Now when you run:
    #
    #   registry.current_scope(Board)
    #
    # You will obtain whatever was defined in +some_new_scope+.
    class ScopeRegistry # :nodoc:
      class << self
        delegate :current_scope, :set_current_scope, :ignore_default_scope, :set_ignore_default_scope,
          :global_current_scope, :set_global_current_scope, to: :instance

        def instance
          ActiveSupport::IsolatedExecutionState[:active_record_scope_registry] ||= new
        end
      end

      def initialize
        @current_scope        = {}
        @ignore_default_scope = {}
        @global_current_scope = {}
      end

      def current_scope(model, skip_inherited_scope = false)
        value_for(@current_scope, model, skip_inherited_scope)
      end

      def set_current_scope(model, value)
        set_value_for(@current_scope, model, value)
      end

      def ignore_default_scope(model, skip_inherited_scope = false)
        value_for(@ignore_default_scope, model, skip_inherited_scope)
      end

      def set_ignore_default_scope(model, value)
        set_value_for(@ignore_default_scope, model, value)
      end

      def global_current_scope(model, skip_inherited_scope = false)
        value_for(@global_current_scope, model, skip_inherited_scope)
      end

      def set_global_current_scope(model, value)
        set_value_for(@global_current_scope, model, value)
      end

      private
        # Obtains the value for a given +scope_type+ and +model+.
        def value_for(scope_type, model, skip_inherited_scope = false)
          return scope_type[model.name] if skip_inherited_scope
          klass = model
          base = model.base_class
          while klass <= base
            value = scope_type[klass.name]
            return value if value
            klass = klass.superclass
          end
        end

        # Sets the +value+ for a given +scope_type+ and +model+.
        def set_value_for(scope_type, model, value)
          scope_type[model.name] = value
        end
    end
  end
end
