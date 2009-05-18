module ActiveSupport
  # If true, use ISO 8601 format for dates and times. Otherwise, fall back to the Active Support legacy format.
  mattr_accessor :use_standard_json_time_format
  # Look for and parse json strings that look like ISO 8601 times.
  mattr_accessor :parse_json_times

  module JSON
    # matches YAML-formatted dates
    DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?))$/

    module Encoding #:nodoc:
      mattr_accessor :escape_regex

      ESCAPED_CHARS = {
        "\010" =>  '\b',
        "\f"   =>  '\f',
        "\n"   =>  '\n',
        "\r"   =>  '\r',
        "\t"   =>  '\t',
        '"'    =>  '\"',
        '\\'   =>  '\\\\',
        '>'    =>  '\u003E',
        '<'    =>  '\u003C',
        '&'    =>  '\u0026'
      }

      def self.escape(string)
        json = '"' + string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }
        json.force_encoding('ascii-8bit') if respond_to?(:force_encoding)
        json.gsub(/([\xC0-\xDF][\x80-\xBF]|
                 [\xE0-\xEF][\x80-\xBF]{2}|
                 [\xF0-\xF7][\x80-\xBF]{3})+/nx) { |s|
          s.unpack("U*").pack("n*").unpack("H*")[0].gsub(/.{4}/, '\\\\u\&')
        } + '"'
      end
    end

    class << self
      delegate :decode, :to => :backend

      def backend
        @backend || begin
          self.backend = "Yaml"
          @backend
        end
      end

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
    attr_reader :escape_html_entities_in_json

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

ActiveSupport.escape_html_entities_in_json = true

require 'active_support/json/encoding'
