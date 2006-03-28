module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
        XML_TYPE_NAMES = {
          "Fixnum"     => "integer",
          "Date"       => "date",
          "Time"       => "datetime",
          "TrueClass"  => "boolean",
          "FalseClass" => "boolean"
        }
        
        XML_FORMATTING = {
          "date"     => Proc.new { |date| date.to_s(:db) },
          "datetime" => Proc.new { |time| time.xmlschema }
        }
        
        def to_xml(options = {})
          options[:indent] ||= 2
          options.reverse_merge!({ :builder => Builder::XmlMarkup.new(:indent => options[:indent]), :root => "hash" })
          options[:builder].instruct! unless options.delete(:skip_instruct)

          options[:builder].__send__(options[:root].to_s.dasherize) do
            each do |key, value|
              case value
                when ::Hash
                  value.to_xml(options.merge({ :root => key, :skip_instruct => true }))
                when ::Array
                  value.to_xml(options.merge({ :root => key, :children => key.to_s.singularize, :skip_instruct => true}))
                else
                  type_name = XML_TYPE_NAMES[value.class.to_s]

                  options[:builder].tag!(key.to_s.dasherize, 
                    XML_FORMATTING[type_name] ? XML_FORMATTING[type_name].call(value) : value,
                    options[:skip_types] || value.nil? || type_name.nil? ? { } : { :type => type_name }
                  )
              end
            end
          end
        end
      end
    end
  end
end
