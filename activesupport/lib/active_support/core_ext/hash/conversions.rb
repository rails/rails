module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Hash #:nodoc:
      module Conversions
        XML_TYPE_NAMES = {
          "String" => "string",
          "Fixnum" => "integer",
          "Date"   => "date",
          "Time"   => "datetime"
        }
        
        XML_FORMATTING = {
          "date"     => Proc.new { |date| date.to_s(:db) },
          "datetime" => Proc.new { |time| time.to_s(:db) }
        }
        
        def to_xml(options = {})
          options.reverse_merge!({ :builder => Builder::XmlMarkup.new, :root => "hash" })

          options[:builder].__send__(options[:root]) do
            for key in keys
              value = self[key]

              if value.is_a?(self.class)
                value.to_xml(:builder => options[:builder], :root => key)
              else
                type_name = XML_TYPE_NAMES[value.class.to_s]
                options[:builder].__send__(key.to_s.dasherize, 
                  XML_FORMATTING[type_name] ? XML_FORMATTING[type_name].call(value) : value,
                  value.nil? ? { } : { :type => type_name }
                )
              end
            end
          end
        end
      end
    end
  end
end
