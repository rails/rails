require 'active_support/time'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/hash/reverse_merge'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string/inflections'

class Hash
  # This module exists to decorate files deserialized using Hash.from_xml with
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

  XML_TYPE_NAMES = {
    "Symbol"     => "symbol",
    "Fixnum"     => "integer",
    "Bignum"     => "integer",
    "BigDecimal" => "decimal",
    "Float"      => "float",
    "TrueClass"  => "boolean",
    "FalseClass" => "boolean",
    "Date"       => "date",
    "DateTime"   => "datetime",
    "Time"       => "datetime"
  } unless defined?(XML_TYPE_NAMES)

  XML_FORMATTING = {
    "symbol"   => Proc.new { |symbol| symbol.to_s },
    "date"     => Proc.new { |date| date.to_s(:db) },
    "datetime" => Proc.new { |time| time.xmlschema },
    "binary"   => Proc.new { |binary| ActiveSupport::Base64.encode64(binary) },
    "yaml"     => Proc.new { |yaml| yaml.to_yaml }
  } unless defined?(XML_FORMATTING)

  # TODO: use Time.xmlschema instead of Time.parse;
  #       use regexp instead of Date.parse
  unless defined?(XML_PARSING)
    XML_PARSING = {
      "symbol"       => Proc.new  { |symbol|  symbol.to_sym },
      "date"         => Proc.new  { |date|    ::Date.parse(date) },
      "datetime"     => Proc.new  { |time|    ::Time.parse(time).utc rescue ::DateTime.parse(time).utc },
      "integer"      => Proc.new  { |integer| integer.to_i },
      "float"        => Proc.new  { |float|   float.to_f },
      "decimal"      => Proc.new  { |number|  BigDecimal(number) },
      "boolean"      => Proc.new  { |boolean| %w(1 true).include?(boolean.strip) },
      "string"       => Proc.new  { |string|  string.to_s },
      "yaml"         => Proc.new  { |yaml|    YAML::load(yaml) rescue yaml },
      "base64Binary" => Proc.new  { |bin|     ActiveSupport::Base64.decode64(bin) },
      "binary"       => Proc.new do |bin, entity|
        case entity['encoding']
	  when 'base64'
	    ActiveSupport::Base64.decode64(bin)
	  # TODO: Add support for other encodings
	  else
	    bin
	end
      end,
      "file"         => Proc.new do |file, entity|
        f = StringIO.new(ActiveSupport::Base64.decode64(file))
        f.extend(FileLike)
        f.original_filename = entity['name']
        f.content_type = entity['content_type']
        f
      end
    }

    XML_PARSING.update(
      "double"   => XML_PARSING["float"],
      "dateTime" => XML_PARSING["datetime"]
    )
  end

  # Returns a string containing an XML representation of its receiver:
  # 
  #   {"foo" => 1, "bar" => 2}.to_xml
  #   # =>
  #   # <?xml version="1.0" encoding="UTF-8"?>
  #   # <hash>
  #   #   <foo type="integer">1</foo>
  #   #   <bar type="integer">2</bar>
  #   # </hash>
  # 
  # To do so, the method loops over the pairs and builds nodes that depend on
  # the _values_. Given a pair +key+, +value+:
  # 
  # * If +value+ is a hash there's a recursive call with +key+ as <tt>:root</tt>.
  # 
  # * If +value+ is an array there's a recursive call with +key+ as <tt>:root</tt>,
  #   and +key+ singularized as <tt>:children</tt>.
  # 
  # * If +value+ is a callable object it must expect one or two arguments. Depending
  #   on the arity, the callable is invoked with the +options+ hash as first argument
  #   with +key+ as <tt>:root</tt>, and +key+ singularized as second argument. Its
  #   return value becomes a new node.
  # 
  # * If +value+ responds to +to_xml+ the method is invoked with +key+ as <tt>:root</tt>.
  # 
  # * Otherwise, a node with +key+ as tag is created with a string representation of
  #   +value+ as text node. If +value+ is +nil+ an attribute "nil" set to "true" is added.
  #   Unless the option <tt>:skip_types</tt> exists and is true, an attribute "type" is
  #   added as well according to the following mapping:
  #
  #     XML_TYPE_NAMES = {
  #       "Symbol"     => "symbol",
  #       "Fixnum"     => "integer",
  #       "Bignum"     => "integer",
  #       "BigDecimal" => "decimal",
  #       "Float"      => "float",
  #       "TrueClass"  => "boolean",
  #       "FalseClass" => "boolean",
  #       "Date"       => "date",
  #       "DateTime"   => "datetime",
  #       "Time"       => "datetime"
  #     }
  # 
  # By default the root node is "hash", but that's configurable via the <tt>:root</tt> option.
  # 
  # The default XML builder is a fresh instance of <tt>Builder::XmlMarkup</tt>. You can
  # configure your own builder with the <tt>:builder</tt> option. The method also accepts
  # options like <tt>:dasherize</tt> and friends, they are forwarded to the builder.
  def to_xml(options = {})
    require 'builder' unless defined?(Builder)

    options = options.dup
    options[:indent] ||= 2
    options.reverse_merge!({ :builder => Builder::XmlMarkup.new(:indent => options[:indent]),
                             :root => "hash" })
    options[:builder].instruct! unless options.delete(:skip_instruct)
    root = rename_key(options[:root].to_s, options)

    options[:builder].__send__(:method_missing, root) do
      each do |key, value|
        case value
          when ::Hash
            value.to_xml(options.merge({ :root => key, :skip_instruct => true }))
          when ::Array
            value.to_xml(options.merge({ :root => key, :children => key.to_s.singularize, :skip_instruct => true}))
          when ::Method, ::Proc
            # If the Method or Proc takes two arguments, then
            # pass the suggested child element name.  This is
            # used if the Method or Proc will be operating over
            # multiple records and needs to create an containing
            # element that will contain the objects being
            # serialized.
            if 1 == value.arity
              value.call(options.merge({ :root => key, :skip_instruct => true }))
            else
              value.call(options.merge({ :root => key, :skip_instruct => true }), key.to_s.singularize)
            end
          else
            if value.respond_to?(:to_xml)
              value.to_xml(options.merge({ :root => key, :skip_instruct => true }))
            else
              type_name = XML_TYPE_NAMES[value.class.name]

              key = rename_key(key.to_s, options)

              attributes = options[:skip_types] || value.nil? || type_name.nil? ? { } : { :type => type_name }
              if value.nil?
                attributes[:nil] = true
              end

              options[:builder].tag!(key,
                XML_FORMATTING[type_name] ? XML_FORMATTING[type_name].call(value) : value,
                attributes
              )
            end
        end
      end
      
      yield options[:builder] if block_given?
    end

  end

  def rename_key(key, options = {})
    camelize = options.has_key?(:camelize) && options[:camelize]
    dasherize = !options.has_key?(:dasherize) || options[:dasherize]
    key = key.camelize if camelize
    dasherize ? key.dasherize : key
  end

  class << self
    def from_xml(xml)
      typecast_xml_value(unrename_keys(ActiveSupport::XmlMini.parse(xml)))
    end

    private
      def typecast_xml_value(value)
        case value.class.to_s
          when 'Hash'
            if value['type'] == 'array'
              child_key, entries = Array.wrap(value.detect { |k,v| k != 'type' })   # child_key is throwaway
              if entries.nil? || (c = value['__content__'] && c.blank?)
                []
              else
                case entries.class.to_s   # something weird with classes not matching here.  maybe singleton methods breaking is_a?
                when "Array"
                  entries.collect { |v| typecast_xml_value(v) }
                when "Hash"
                  [typecast_xml_value(entries)]
                else
                  raise "can't typecast #{entries.inspect}"
                end
              end
            elsif value.has_key?("__content__")
              content = value["__content__"]
              if parser = XML_PARSING[value["type"]]
                if parser.arity == 2
                  XML_PARSING[value["type"]].call(content, value)
                else
                  XML_PARSING[value["type"]].call(content)
                end
              else
                content
              end
            elsif value['type'] == 'string' && value['nil'] != 'true'
              ""
            # blank or nil parsed values are represented by nil
            elsif value.blank? || value['nil'] == 'true'
              nil
            # If the type is the only element which makes it then 
            # this still makes the value nil, except if type is
            # a XML node(where type['value'] is a Hash)
            elsif value['type'] && value.size == 1 && !value['type'].is_a?(::Hash)
              nil
            else
              xml_value = value.inject({}) do |h,(k,v)|
                h[k] = typecast_xml_value(v)
                h
              end
              
              # Turn { :files => { :file => #<StringIO> } into { :files => #<StringIO> } so it is compatible with
              # how multipart uploaded files from HTML appear
              xml_value["file"].is_a?(StringIO) ? xml_value["file"] : xml_value
            end
          when 'Array'
            value.map! { |i| typecast_xml_value(i) }
            case value.length
              when 0 then nil
              when 1 then value.first
              else value
            end
          when 'String'
            value
          else
            raise "can't typecast #{value.class.name} - #{value.inspect}"
        end
      end

      def unrename_keys(params)
        case params.class.to_s
          when "Hash"
            params.inject({}) do |h,(k,v)|
              h[k.to_s.tr("-", "_")] = unrename_keys(v)
              h
            end
          when "Array"
            params.map { |v| unrename_keys(v) }
          else
            params
        end
      end
  end
end
