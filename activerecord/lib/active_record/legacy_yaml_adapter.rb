# frozen_string_literal: true

module ActiveRecord
  module LegacyYamlAdapter # :nodoc:
    def self.convert(coder)
      return coder unless coder.is_a?(Psych::Coder)

      case coder["active_record_yaml_version"]
      when 1, 2 then coder
      else
        raise("Active Record doesn't know how to load YAML with this format.")
      end
    end
  end
end
