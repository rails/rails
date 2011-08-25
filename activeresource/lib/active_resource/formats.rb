module ActiveResource
  module Formats
    autoload :XmlFormat, 'active_resource/formats/xml_format'
    autoload :JsonFormat, 'active_resource/formats/json_format'

    # Lookup the format class from a mime type reference symbol. Example:
    #
    #   ActiveResource::Formats[:xml]  # => ActiveResource::Formats::XmlFormat
    #   ActiveResource::Formats[:json] # => ActiveResource::Formats::JsonFormat
    def self.[](mime_type_reference)
      ActiveResource::Formats.const_get(ActiveSupport::Inflector.camelize(mime_type_reference.to_s) + "Format")
    end

    def self.remove_root(data)
      if data.is_a?(Hash) && data.keys.size == 1 && [Array,Hash].any?{ |c| data.first.last.is_a?(c) }
        data.values.first
      else
        data
      end
    end
  end
end
