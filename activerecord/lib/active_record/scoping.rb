module ActiveRecord
  module Scoping
    extend ActiveSupport::Concern

    included do
      include Default
      include Named
    end

    module ClassMethods
      def current_scope #:nodoc:
        ScopeRegistry.current.value_for(:current_scope, base_class.to_s)
      end

      def current_scope=(scope) #:nodoc:
        ScopeRegistry.current.set_value_for(:current_scope, base_class.to_s, scope)
      end
    end

    def populate_with_current_scope_attributes
      return unless self.class.scope_attributes?

      self.class.scope_attributes.each do |att,value|
        send("#{att}=", value) if respond_to?("#{att}=")
      end
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
    #   registry = ActiveRecord::Scoping::ScopeRegistry.current
    #   registry.set_value_for(:current_scope, "Board", some_new_scope)
    #
    # Now when you run:
    #
    #   registry.value_for(:current_scope, "Board")
    #
    # You will obtain whatever was defined in +some_new_scope+.
    class ScopeRegistry # :nodoc:
      def self.current
        Thread.current["scope_registry"] ||= new
      end

      VALID_SCOPE_TYPES = [:current_scope, :ignore_default_scope]

      attr_accessor :registry

      def initialize
        @registry = Hash.new { |hash, key| hash[key] = {} }
      end

      # Obtains the value for a given +scope_name+ and +variable_name+.
      def value_for(scope_type, variable_name)
        raise_invalid_scope_type!(scope_type)
        @registry[scope_type][variable_name]
      end

      # Sets the +value+ for a given +scope_type+ and +variable_name+.
      def set_value_for(scope_type, variable_name, value)
        raise_invalid_scope_type!(scope_type)
        @registry[scope_type][variable_name] = value
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
