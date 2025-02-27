# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/duplicable"

module ActiveModel
  class AttributeMutationTracker # :nodoc:
    OPTION_NOT_GIVEN = Object.new.freeze

    def initialize(attributes)
      @attributes = attributes
    end

    def changed_attribute_names
      attr_names.select { |attr_name| changed?(attr_name) }
    end

    def changed_values
      attr_names.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |attr_name, result|
        if changed?(attr_name)
          result.store(attr_name, original_value(attr_name), convert_value: false)
        end
      end
    end

    def changes
      attr_names.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |attr_name, result|
        if change = change_to_attribute(attr_name)
          result.store(attr_name, change, convert_value: false)
        end
      end
    end

    def change_to_attribute(attr_name)
      if changed?(attr_name)
        [original_value(attr_name), fetch_value(attr_name)]
      end
    end

    def any_changes?
      attr_names.any? { |attr| changed?(attr) }
    end

    def changed?(attr_name, from: OPTION_NOT_GIVEN, to: OPTION_NOT_GIVEN)
      attribute_changed?(attr_name) &&
        (OPTION_NOT_GIVEN == from || original_value(attr_name) == type_cast(attr_name, from)) &&
        (OPTION_NOT_GIVEN == to || fetch_value(attr_name) == type_cast(attr_name, to))
    end

    def changed_in_place?(attr_name)
      attributes[attr_name].changed_in_place?
    end

    def forget_change(attr_name)
      attributes[attr_name] = attributes[attr_name].forgetting_assignment
      forced_changes.delete(attr_name)
    end

    def original_value(attr_name)
      attributes[attr_name].original_value
    end

    def force_change(attr_name)
      forced_changes[attr_name] = fetch_value(attr_name)
    end

    private
      attr_reader :attributes

      def forced_changes
        @forced_changes ||= {}
      end

      def attr_names
        attributes.keys
      end

      def attribute_changed?(attr_name)
        forced_changes.include?(attr_name) || !!attributes[attr_name].changed?
      end

      def fetch_value(attr_name)
        attributes.fetch_value(attr_name)
      end

      def type_cast(attr_name, value)
        attributes[attr_name].type_cast(value)
      end
  end

  class ForcedMutationTracker < AttributeMutationTracker # :nodoc:
    def initialize(attributes)
      super
      @finalized_changes = nil
    end

    def changed_in_place?(attr_name)
      false
    end

    def change_to_attribute(attr_name)
      if finalized_changes&.include?(attr_name)
        finalized_changes[attr_name].dup
      else
        super
      end
    end

    def forget_change(attr_name)
      forced_changes.delete(attr_name)
    end

    def original_value(attr_name)
      if changed?(attr_name)
        forced_changes[attr_name]
      else
        fetch_value(attr_name)
      end
    end

    def force_change(attr_name)
      forced_changes[attr_name] = clone_value(attr_name) unless attribute_changed?(attr_name)
    end

    def finalize_changes
      @finalized_changes = changes
    end

    private
      attr_reader :finalized_changes

      def attr_names
        forced_changes.keys
      end

      def attribute_changed?(attr_name)
        forced_changes.include?(attr_name)
      end

      def fetch_value(attr_name)
        attributes.send(:_read_attribute, attr_name)
      end

      def clone_value(attr_name)
        value = fetch_value(attr_name)
        value.duplicable? ? value.clone : value
      rescue TypeError, NoMethodError
        value
      end

      def type_cast(attr_name, value)
        value
      end
  end

  class NullMutationTracker # :nodoc:
    include Singleton

    def changed_attribute_names
      []
    end

    def changed_values
      {}
    end

    def changes
      {}
    end

    def change_to_attribute(attr_name)
    end

    def any_changes?
      false
    end

    def changed?(attr_name, **)
      false
    end

    def changed_in_place?(attr_name)
      false
    end

    def original_value(attr_name)
    end
  end
end
