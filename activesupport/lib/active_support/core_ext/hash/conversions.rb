require 'date'
require 'active_support/core_ext/module/attribute_accessors'

module ActiveSupport #:nodoc:
  # these accessors are here because people using ActiveResource and REST to integrate with other systems
  # have to be able to control the default behavior of rename_key. dasherize_xml is set to true to emulate
  # existing behavior. In a future version it should be set to false by default.
  mattr_accessor :dasherize_xml
  mattr_accessor :camelize_xml
  self.dasherize_xml = true
  self.camelize_xml  = false
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
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
          "Time"       => "datetime",
          "ActiveSupport::TimeWithZone" => "datetime"
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

        def self.included(klass)
          klass.extend(ClassMethods)
        end

        # Converts a hash into a string suitable for use as a URL query string. An optional <tt>namespace</tt> can be
        # passed to enclose the param names (see example below).
        #
        # ==== Examples
        #   { :name => 'David', :nationality => 'Danish' }.to_query # => "name=David&nationality=Danish"
        #
        #   { :name => 'David', :nationality => 'Danish' }.to_query('user') # => "user%5Bname%5D=David&user%5Bnationality%5D=Danish"
        def to_query(namespace = nil)
          collect do |key, value|
            value.to_query(namespace ? "#{namespace}[#{key}]" : key)
          end.sort * '&'
        end
        
        alias_method :to_param, :to_query

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
          camelize  = options.has_key?(:camelize) ? options[:camelize]   : ActiveSupport.camelize_xml
          dasherize = options.has_key?(:dasherize) ? options[:dasherize] : ActiveSupport.dasherize_xml
          key = key.camelize if camelize
          key = key.dasherize if dasherize
          key
        end

        module ClassMethods
          def from_xml(xml)
            typecast_xml_value(unrename_keys(XmlMini.parse(xml)))
          end

          private
            def typecast_xml_value(value)
              case value.class.to_s
                when 'Hash'
                  if value['type'] == 'array'
                    child_key, entries = value.detect { |k,v| k != 'type' }   # child_key is throwaway
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
    end
  end
end
