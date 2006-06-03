require 'date'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
        XML_TYPE_NAMES = {
          ::Fixnum     => "integer",
          ::Float      => "float",
          ::Date       => "date",
          ::DateTime   => "datetime",
          ::Time       => "datetime",
          ::TrueClass  => "boolean",
          ::FalseClass => "boolean"
        }

        XML_FORMATTING = {
          "date"     => Proc.new { |date| date.to_s(:db) },
          "datetime" => Proc.new { |time| time.xmlschema }
        }

        def to_xml(options = {})
          options[:indent] ||= 2
          options.reverse_merge!({ :builder => Builder::XmlMarkup.new(:indent => options[:indent]),
                                   :root => "hash" })
          options[:builder].instruct! unless options.delete(:skip_instruct)
          dasherize = !options.has_key?(:dasherize) || options[:dasherize]
          root = dasherize ? options[:root].to_s.dasherize : options[:root].to_s

          options[:builder].__send__(root) do
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
                    type_name = XML_TYPE_NAMES[value.class]

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
      end
    end
  end
end
