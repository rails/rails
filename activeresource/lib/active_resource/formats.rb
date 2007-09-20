module ActiveResource
  module Formats
    # Lookup the format class from a mime type reference symbol. Example:
    #
    #   ActiveResource::Formats[:xml]  # => ActiveResource::Formats::XmlFormat
    #   ActiveResource::Formats[:json] # => ActiveResource::Formats::JsonFormat
    def self.[](mime_type_reference)
      ActiveResource::Formats.const_get(mime_type_reference.to_s.camelize + "Format")
    end
  end
end

require 'active_resource/formats/xml_format'
require 'active_resource/formats/json_format'