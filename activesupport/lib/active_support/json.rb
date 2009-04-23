require 'active_support/core_ext/module/delegation'
require 'active_support/core_ext/module/attribute_accessors'

module ActiveSupport
  # If true, use ISO 8601 format for dates and times. Otherwise, fall back to the Active Support legacy format.
  mattr_accessor :use_standard_json_time_format
  # Look for and parse json strings that look like ISO 8601 times.
  mattr_accessor :parse_json_times

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    class << self
      attr_reader :backend
      delegate :decode, :to => :backend
    
      def backend=(name)
        if name.is_a?(Module)
          @backend = name
        else
          require "active_support/json/backends/#{name.to_s.downcase}.rb"
          @backend = ActiveSupport::JSON::Backends::const_get(name)
        end
      end
    
      def with_backend(name)
        old_backend, self.backend = backend, name
        yield
      ensure
        self.backend = old_backend
      end
    end
  end

  class << self
    def escape_html_entities_in_json
      @escape_html_entities_in_json
    end

    def escape_html_entities_in_json=(value)
      ActiveSupport::JSON::Encoding.escape_regex = \
        if value
          /[\010\f\n\r\t"\\><&]/
        else
          /[\010\f\n\r\t"\\]/
        end
      @escape_html_entities_in_json = value
    end
  end

  JSON.backend = 'Yaml'
end

require 'active_support/json/encoding'