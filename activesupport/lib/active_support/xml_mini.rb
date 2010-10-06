require 'active_support/core_ext/module/delegation'

module ActiveSupport
  # = XmlMini
  #
  # To use the much faster libxml parser:
  #   gem 'libxml-ruby', '=0.9.7'
  #   XmlMini.backend = 'LibXML'
  module XmlMini
    extend self

    # This module decorates files deserialized using Hash.from_xml with
    # the <tt>original_filename</tt> and <tt>content_type</tt> methods.
    module FileLike #:nodoc:
      attr_writer :original_filename, :content_type

      def original_filename
        @original_filename || 'untitled'
      end

      def content_type
        @content_type || 'application/octet-stream'
      end
    end

    DEFAULT_ENCODINGS = {
      "binary" => "base64"
    } unless defined?(DEFAULT_ENCODINGS)

    TYPE_NAMES = {
      "Symbol"     => "symbol",
      "Fixnum"     => "integer",
      "Bignum"     => "integer",
      "BigDecimal" => "decimal",
      "Float"      => "float",
      "TrueClass"  => "boolean",
      "FalseClass" => "boolean",
      "Date"       => "date",
      "DateTime"   => "datetime",
      "Time"       => "datetime",
      "Array"      => "array",
      "Hash"       => "hash"
    } unless defined?(TYPE_NAMES)

    FORMATTING = {
      "symbol"   => Proc.new { |symbol| symbol.to_s },
      "date"     => Proc.new { |date| date.to_s(:db) },
      "datetime" => Proc.new { |time| time.xmlschema },
      "binary"   => Proc.new { |binary| ActiveSupport::Base64.encode64(binary) },
      "yaml"     => Proc.new { |yaml| yaml.to_yaml }
    } unless defined?(FORMATTING)

    # TODO: use Time.xmlschema instead of Time.parse;
    #       use regexp instead of Date.parse
    unless defined?(PARSING)
      PARSING = {
        "symbol"       => Proc.new { |symbol|  symbol.to_sym },
        "date"         => Proc.new { |date|    ::Date.parse(date) },
        "datetime"     => Proc.new { |time|    ::Time.parse(time).utc rescue ::DateTime.parse(time).utc },
        "integer"      => Proc.new { |integer| integer.to_i },
        "float"        => Proc.new { |float|   float.to_f },
        "decimal"      => Proc.new { |number|  BigDecimal(number) },
        "boolean"      => Proc.new { |boolean| %w(1 true).include?(boolean.strip) },
        "string"       => Proc.new { |string|  string.to_s },
        "yaml"         => Proc.new { |yaml|    YAML::load(yaml) rescue yaml },
        "base64Binary" => Proc.new { |bin|     ActiveSupport::Base64.decode64(bin) },
        "binary"       => Proc.new { |bin, entity| _parse_binary(bin, entity) },
        "file"         => Proc.new { |file, entity| _parse_file(file, entity) }
      }

      PARSING.update(
        "double"   => PARSING["float"],
        "dateTime" => PARSING["datetime"]
      )
    end

    attr_reader :backend
    delegate :parse, :to => :backend

    def backend=(name)
      if name.is_a?(Module)
        @backend = name
      else
        require "active_support/xml_mini/#{name.to_s.downcase}"
        @backend = ActiveSupport.const_get("XmlMini_#{name}")
      end
    end

    def with_backend(name)
      old_backend, self.backend = backend, name
      yield
    ensure
      self.backend = old_backend
    end

    def to_tag(key, value, options)
      type_name = options.delete(:type)
      merged_options = options.merge(:root => key, :skip_instruct => true)

      if value.is_a?(::Method) || value.is_a?(::Proc)
        if value.arity == 1
          value.call(merged_options)
        else
          value.call(merged_options, key.to_s.singularize)
        end
      elsif value.respond_to?(:to_xml)
        value.to_xml(merged_options)
      else
        type_name ||= TYPE_NAMES[value.class.name]
        type_name ||= value.class.name if value && !value.respond_to?(:to_str)
        type_name   = type_name.to_s   if type_name

        key = rename_key(key.to_s, options)

        attributes = options[:skip_types] || type_name.nil? ? { } : { :type => type_name }
        attributes[:nil] = true if value.nil?

        encoding = options[:encoding] || DEFAULT_ENCODINGS[type_name]
        attributes[:encoding] = encoding if encoding

        formatted_value = FORMATTING[type_name] && !value.nil? ?
          FORMATTING[type_name].call(value) : value

        options[:builder].tag!(key, formatted_value, attributes)
      end
    end

    def rename_key(key, options = {})
      camelize  = options.has_key?(:camelize) && options[:camelize]
      dasherize = !options.has_key?(:dasherize) || options[:dasherize]
      key = key.camelize  if camelize
      key = _dasherize(key) if dasherize
      key
    end

    protected

    def _dasherize(key)
      key.gsub(/(?!^[_]*)_(?![_]*$)/, '-')
    end

	  # TODO: Add support for other encodings
    def _parse_binary(bin, entity) #:nodoc:
      case entity['encoding']
      when 'base64'
        ActiveSupport::Base64.decode64(bin)
      else
        bin
      end
    end

    def _parse_file(file, entity)
      f = StringIO.new(ActiveSupport::Base64.decode64(file))
      f.extend(FileLike)
      f.original_filename = entity['name']
      f.content_type = entity['content_type']
      f
    end
  end

  XmlMini.backend = 'REXML'
end
