class Hash
  module XmlValue
    def xml_value(key, value, options)
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
        #yield options[:builder] if block_given?
    end

    def rename_key(key, options = {})
      camelize = options.has_key?(:camelize) && options[:camelize]
      dasherize = !options.has_key?(:dasherize) || options[:dasherize]
      key = key.camelize if camelize
      dasherize ? key.dasherize : key
    end
  end
end

