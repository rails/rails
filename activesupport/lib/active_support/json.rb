module ActiveSupport
  # If true, use ISO 8601 format for dates and times.  Otherwise, fall back to the Active Support legacy format.
  mattr_accessor :use_standard_json_time_format

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
end

require 'active_support/json/encoding'
require 'active_support/json/decoding'
