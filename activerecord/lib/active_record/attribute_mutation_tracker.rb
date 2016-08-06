module ActiveRecord
  class AttributeMutationTracker # :nodoc:
    def initialize(attributes)
      @attributes = attributes
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
        if changed?(attr_name)
          result[attr_name] = [attributes[attr_name].original_value, attributes.fetch_value(attr_name)]
        end
      end
    end

    def changed?(attr_name)
      attr_name = attr_name.to_s
      attributes[attr_name].changed?
    end

    def changed_in_place?(attr_name)
      attributes[attr_name].changed_in_place?
    end

    def forget_change(attr_name)
      attr_name = attr_name.to_s
      attributes[attr_name] = attributes[attr_name].forgetting_assignment
    end

    protected

      attr_reader :attributes

    private

      def attr_names
        attributes.keys
      end
  end

  class NullMutationTracker # :nodoc:
    include Singleton

    def changed_values
      {}
    end

    def changes
      {}
    end

    def changed?(*)
      false
    end

    def changed_in_place?(*)
      false
    end

    def forget_change(*)
    end
  end
end
