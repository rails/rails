module ActiveRecord
  class AttributeMutationTracker # :nodoc:
    def initialize(attributes, original_attributes)
      @attributes = attributes
      @original_attributes = original_attributes
    end

    def changed_values
      attr_names.each_with_object({}.with_indifferent_access) do |attr_name, result|
        if changed?(attr_name)
          result[attr_name] = original_attributes.fetch_value(attr_name)
        end
      end
    end

    def changes
      attr_names.each_with_object({}.with_indifferent_access) do |attr_name, result|
        if changed?(attr_name)
          result[attr_name] = [original_attributes.fetch_value(attr_name), attributes.fetch_value(attr_name)]
        end
      end
    end

    def changed?(attr_name)
      attr_name = attr_name.to_s
      modified?(attr_name) || changed_in_place?(attr_name)
    end

    def changed_in_place?(attr_name)
      original_database_value = original_attributes[attr_name].value_before_type_cast
      attributes[attr_name].changed_in_place_from?(original_database_value)
    end

    def forget_change(attr_name)
      attr_name = attr_name.to_s
      original_attributes[attr_name] = attributes[attr_name].dup
    end

    def now_tracking(new_attributes)
      AttributeMutationTracker.new(new_attributes, clean_copy_of(new_attributes))
    end

    protected

    attr_reader :attributes, :original_attributes

    private

    def attr_names
      attributes.keys
    end

    def modified?(attr_name)
      attributes[attr_name].changed_from?(original_attributes.fetch_value(attr_name))
    end

    def clean_copy_of(attributes)
      attributes.map do |attr|
        attr.with_value_from_database(attr.value_for_database)
      end
    end
  end

  class NullMutationTracker # :nodoc:
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
