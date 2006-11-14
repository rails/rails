require 'date'
require 'xml_simple'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
        XML_TYPE_NAMES = {
          "Fixnum"     => "integer",
          "Bignum"     => "integer",
          "BigDecimal" => "numeric",
          "Float"      => "float",
          "Date"       => "date",
          "DateTime"   => "datetime",
          "Time"       => "datetime",
          "TrueClass"  => "boolean",
          "FalseClass" => "boolean"
        } unless defined? XML_TYPE_NAMES

        XML_FORMATTING = {
          "date"     => Proc.new { |date| date.to_s(:db) },
          "datetime" => Proc.new { |time| time.xmlschema },
          "binary"   => Proc.new { |binary| Base64.encode64(binary) }
        } unless defined? XML_FORMATTING

        def self.included(klass)
          klass.extend(ClassMethods)
        end

        def to_xml(options = {})
          options[:indent] ||= 2
          options.reverse_merge!({ :builder => Builder::XmlMarkup.new(:indent => options[:indent]),
                                   :root => "hash" })
          options[:builder].instruct! unless options.delete(:skip_instruct)
          dasherize = !options.has_key?(:dasherize) || options[:dasherize]
          root = dasherize ? options[:root].to_s.dasherize : options[:root].to_s

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

                    key = dasherize ? key.to_s.dasherize : key.to_s

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
          end

        end

        module ClassMethods
          def from_xml(xml)
            # TODO: Refactor this into something much cleaner that doesn't rely on XmlSimple
            undasherize_keys(typecast_xml_value(XmlSimple.xml_in(xml,
              'forcearray'   => false,
              'forcecontent' => true,
              'keeproot'     => true,
              'contentkey'   => '__content__')
            ))            
          end
          
          def create_from_xml(xml)
            ActiveSupport::Deprecation.warn("Hash.create_from_xml has been renamed to Hash.from_xml", caller)
            from_xml(xml)
          end

          private
            def typecast_xml_value(value)
              case value.class.to_s
                when "Hash"
                  if value.has_key?("__content__")
                    content = translate_xml_entities(value["__content__"])
                    case value["type"]
                      when "integer"  then content.to_i
                      when "boolean"  then content.strip == "true"
                      when "datetime" then ::Time.parse(content).utc
                      when "date"     then ::Date.parse(content)
                      else                 content
                    end
                  else
                    (value.blank? || value['type'] || value['nil'] == 'true') ? nil : value.inject({}) do |h,(k,v)|
                      h[k] = typecast_xml_value(v)
                      h
                    end
                  end
                when "Array"
                  value.map! { |i| typecast_xml_value(i) }
                  case value.length
                    when 0 then nil
                    when 1 then value.first
                    else value
                  end
                when "String"
                  value
                else
                  raise "can't typecast #{value.inspect}"
              end
            end

            def translate_xml_entities(value)
              value.gsub(/&lt;/,   "<").
                    gsub(/&gt;/,   ">").
                    gsub(/&quot;/, '"').
                    gsub(/&apos;/, "'").
                    gsub(/&amp;/,  "&")
            end

            def undasherize_keys(params)
              case params.class.to_s
                when "Hash"
                  params.inject({}) do |h,(k,v)|
                    h[k.to_s.tr("-", "_")] = undasherize_keys(v)
                    h
                  end
                when "Array"
                  params.map { |v| undasherize_keys(v) }
                else
                  params
              end
            end
        end
      end
    end
  end
end
