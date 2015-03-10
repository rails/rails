module ActiveRecord
  module LegacyYamlAdapter
    def self.convert(klass, coder)
      return coder unless coder.is_a?(Psych::Coder)

      case coder["active_record_yaml_version"]
      when 0 then coder
      else
        if coder["attributes"].is_a?(AttributeSet)
          coder
        else
          Rails41.convert(klass, coder)
        end
      end
    end

    module Rails41
      def self.convert(klass, coder)
        attributes = klass.attributes_builder
          .build_from_database(coder["attributes"])
        new_record = coder["attributes"][klass.primary_key].blank?

        {
          "attributes" => attributes,
          "new_record" => new_record,
        }
      end
    end
  end
end
