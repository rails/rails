# frozen_string_literal: true

module ActiveRecord
  module LegacyYamlAdapter # :nodoc:
    def self.convert(klass, coder)
      return coder unless coder.is_a?(Psych::Coder)

      case coder['active_record_yaml_version']
      when 1, 2 then coder
      else
        ActiveSupport::Deprecation.warn(<<-MSG.squish)
          YAML loading from legacy format older than Rails 5.0 is deprecated
          and will be removed in Rails 6.2.
        MSG
        if coder['attributes'].is_a?(ActiveModel::AttributeSet)
          Rails420.convert(klass, coder)
        else
          Rails41.convert(klass, coder)
        end
      end
    end

    module Rails420 # :nodoc:
      def self.convert(klass, coder)
        attribute_set = coder['attributes']

        klass.attribute_names.each do |attr_name|
          attribute = attribute_set[attr_name]
          if attribute.type.is_a?(Delegator)
            type_from_klass = klass.type_for_attribute(attr_name)
            attribute_set[attr_name] = attribute.with_type(type_from_klass)
          end
        end

        coder
      end
    end

    module Rails41 # :nodoc:
      def self.convert(klass, coder)
        attributes = klass.attributes_builder
          .build_from_database(coder['attributes'])
        new_record = coder['attributes'][klass.primary_key].blank?

        {
          'attributes' => attributes,
          'new_record' => new_record,
        }
      end
    end
  end
end
