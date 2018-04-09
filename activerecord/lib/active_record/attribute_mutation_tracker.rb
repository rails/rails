module ActiveRecord
  class AttributeMutationTracker # :nodoc:
    OPTION_NOT_GIVEN = Object.new

    def initialize(attributes)
      @attributes = attributes
      @forced_changes = Set.new
      @deprecated_forced_changes = Set.new
    end

    def changed_attribute_names
      attr_names.select { |attr_name| changed?(attr_name) }
    end

    def changed_values
      attr_names.each_with_object({}.with_indifferent_access) do |attr_name, result|
        if changed?(attr_name)
          result[attr_name] = attributes[attr_name].original_value
        end
      end
    end

    def changes
      attr_names.each_with_object({}.with_indifferent_access) do |attr_name, result|
        change = change_to_attribute(attr_name)
        if change
          result[attr_name] = change
        end
      end
    end

    def change_to_attribute(attr_name)
      attr_name = attr_name.to_s
      if changed?(attr_name)
        [attributes[attr_name].original_value, attributes.fetch_value(attr_name)]
      end
    end

    def any_changes?
      attr_names.any? { |attr| changed?(attr) } || deprecated_forced_changes.any?
    end

    def changed?(attr_name, from: OPTION_NOT_GIVEN, to: OPTION_NOT_GIVEN)
      attr_name = attr_name.to_s
      forced_changes.include?(attr_name) ||
        attributes[attr_name].changed? &&
        (OPTION_NOT_GIVEN == from || attributes[attr_name].original_value == from) &&
        (OPTION_NOT_GIVEN == to || attributes[attr_name].value == to)
    end

    def changed_in_place?(attr_name)
      attributes[attr_name.to_s].changed_in_place?
    end

    def forget_change(attr_name)
      attr_name = attr_name.to_s
      attributes[attr_name] = attributes[attr_name].forgetting_assignment
      forced_changes.delete(attr_name)
    end

    def original_value(attr_name)
      attributes[attr_name.to_s].original_value
    end

    def force_change(attr_name)
      forced_changes << attr_name.to_s
    end

    def deprecated_force_change(attr_name)
      deprecated_forced_changes << attr_name.to_s
    end

    # TODO Change this to private once we've dropped Ruby 2.2 support.
    # Workaround for Ruby 2.2 "private attribute?" warning.
    protected

      attr_reader :attributes, :forced_changes, :deprecated_forced_changes

    private

      def attr_names
        attributes.keys
      end
  end

  class NullMutationTracker # :nodoc:
    include Singleton

    def changed_attribute_names(*)
      []
    end

    def changed_values(*)
      {}
    end

    def changes(*)
      {}
    end

    def change_to_attribute(attr_name)
    end

    def any_changes?(*)
      false
    end

    def changed?(*)
      false
    end

    def changed_in_place?(*)
      false
    end

    def forget_change(*)
    end

    def original_value(*)
    end
  end
end
